-- Window Boundary Monitor  
-- A window boundary monitor designed to work with MiniMeters in single-display setups
-- Gracefully reserves a 32-pixel area at the bottom of the screen for MiniMeters
-- Abort immediately if not running inside Hammerspoon (extra robustness)
if type(hs) ~= "table" then
    error("WindowBoundaryMonitor must be run inside Hammerspoon")
end

local WindowBoundaryMonitor = {}

-- 统一配置表：集中所有可调常量，便于维护
-- Centralised configuration table: tweakable constants live here
WindowBoundaryMonitor.config = {
    -- Pixel height reserved at the bottom of the screen for MiniMeters
    BOUNDARY_HEIGHT = 32,
    -- Interval between window checks, in seconds
    WINDOW_CHECK_INTERVAL = 2,
    -- Delay after a screen configuration change before re-checking, in seconds
    SCREEN_CHANGE_DELAY = 1.0,
    -- Pixel tolerance when determining full-screen windows
    FULLSCREEN_TOLERANCE = 2,
    -- Minimum window height we will guarantee when resizing
    MIN_WINDOW_HEIGHT = 100,
}

-- 为向后兼容保留旧字段（别名）
-- Legacy alias kept for backward compatibility
WindowBoundaryMonitor.BOUNDARY_HEIGHT = WindowBoundaryMonitor.config.BOUNDARY_HEIGHT

-- 排除应用列表 - 仅排除必要的应用
-- List of apps to exclude – only those absolutely necessary
WindowBoundaryMonitor.excludedApps = {
    "Hammerspoon",    -- The Hammerspoon app itself
    "MiniMeters"      -- MiniMeters status bar
}

-- 将排除列表转换为哈希表以实现 O(1) 查找
local excludedAppsSet = {}
for _, app in ipairs(WindowBoundaryMonitor.excludedApps) do
    excludedAppsSet[app] = true
end

-- 存储所有显示器的边界信息
local screenBoundaries = {}

-- 记录窗口状态，防止全屏时的死循环
local windowStates = {}

-- 记录已经打印过全屏日志的窗口，避免重复打印
local fullscreenLoggedWindows = {}

-- 【根据用户反馈，"调整冷却期"功能已移除】

-- 顽固窗口黑名单：记录无法调整的窗口
local stubbornWindows = {}
local STUBBORN_WINDOW_TIMEOUT = 300  -- 黑名单超时5分钟 (基础超时)
local stubbornWindowCounters = {} -- 新增：顽固窗口失败计数器
local MAX_STUBBORN_ATTEMPTS = 20    -- 新增：连续失败20次后加入长期黑名单
local LONG_STUBBORN_TIMEOUT = 3600 -- 新增：长期黑名单超时1小时

-- 定时器用于周期检查
local checkTimer = nil

-- 路径监视器
local pathWatcher = nil

-- 屏幕变更防抖定时器
local screenChangeDebounceTimer = nil

-- 性能优化：缓存可见窗口列表，减少系统调用
local cachedVisibleWindows = {}
local lastWindowCacheTime = 0
local WINDOW_CACHE_TTL = 0.5  -- 窗口缓存有效期（秒）

-- 安全获取窗口应用信息，避免NSRunningApplication错误
local function safeGetWindowApp(window)
    -- 增加更严格的早期退出检查
    if not window or not window:id() then return nil, nil end

    local app, name
    local success = pcall(function()
        app = window:application()
        if app then
            name = app:name()
        end
    end)

    if success and app and name then
        return app, name
    end

    return nil, nil
end

-- 检测窗口是否为真全屏状态（使用缓存的屏幕信息）
local function isWindowFullscreen(window)
    if not window then return false end
    
    local app, appName = safeGetWindowApp(window)
    if not app or not appName then return false end
    local windowFrame = window:frame()
    local screen = window:screen()
    if not screen then return false end
    
    -- 使用缓存的屏幕信息，确保与边界检测一致
    local screenId = screen:id()
    local screenInfo = screenBoundaries[screenId]
    if not screenInfo then 
        -- 如果缓存中没有信息，可能是屏幕刚变更，直接返回false避免误判
        return false 
    end
    
    local fullFrame = screenInfo.fullFrame      -- 从缓存获取完整屏幕信息
    local normalFrame = screenInfo.normalFrame  -- 从缓存获取可用屏幕信息
    
    -- 黑名单：这些应用永远不会有真全屏（即使几何匹配）
    local neverFullscreenApps = {
        "Finder"       -- Finder 的"全屏覆盖"是特殊行为，不是真全屏
    }
    
    for _, excludeApp in ipairs(neverFullscreenApps) do
        if appName == excludeApp then
            return false
        end
    end
    
    -- 增强的全屏检测：使用像素容差 + 百分比容差，兼容 HiDPI/缩放/notch
    local pixTol = WindowBoundaryMonitor.config.FULLSCREEN_TOLERANCE
    local pctTol = 0.01 -- 1% 额外比例容差
    
    -- 辅助函数：比较两个值是否在容差范围
    local function withinTolerance(a, b, dimension)
        local diff = math.abs(a - b)
        return diff <= pixTol or diff <= dimension * pctTol
    end
    
    -- 获取最新 fullFrame（处理菜单栏显隐变化）
    local dynamicFullFrame = screen:fullFrame()
    
    -- 检查是否匹配 fullFrame（缓存或动态获取）
    local function frameMatches(targetFrame)
        return withinTolerance(windowFrame.x, targetFrame.x, targetFrame.w) and
               withinTolerance(windowFrame.y, targetFrame.y, targetFrame.h) and
               withinTolerance(windowFrame.w, targetFrame.w, targetFrame.w) and
               withinTolerance(windowFrame.h, targetFrame.h, targetFrame.h)
    end
    
    local matchesCachedFull = frameMatches(fullFrame)
    local matchesDynamicFull = frameMatches(dynamicFullFrame)
    
    if matchesCachedFull or matchesDynamicFull then
        -- 只在第一次检测到全屏时打印日志
        local windowId = window:id()
        if not fullscreenLoggedWindows[windowId] then
            print(string.format("跳过真全屏窗口: %s", appName))
            fullscreenLoggedWindows[windowId] = true
        end
        return true
    end
    
    return false
end

-- 获取窗口唯一标识（使用安全的应用获取方法）
local function getWindowId(window)
    if not window then return nil end
    local app, appName = safeGetWindowApp(window)
    if not app or not appName then return nil end
    
    local title = ""
    local success, windowTitle = pcall(function()
        return window:title() or ""
    end)
    if success then
        title = windowTitle
    end
    
    return appName .. ":" .. title
end

-- 更新窗口状态并检测变化
local function updateWindowState(window)
    local windowId = getWindowId(window)
    if not windowId then return false end
    
    local isFullscreen = isWindowFullscreen(window)
    local oldState = windowStates[windowId]
    
    windowStates[windowId] = {
        isFullscreen = isFullscreen,
        lastCheck = os.time()
    }
    
    -- 返回是否从全屏变为非全屏（需要重新检查）
    return oldState and oldState.isFullscreen and not isFullscreen
end

-- 获取缓存的可见窗口列表（减少系统调用并增强错误处理）
local function getVisibleWindowsCached()
    local currentTime = os.time()
    
    -- 如果缓存仍有效，直接返回
    if currentTime - lastWindowCacheTime < WINDOW_CACHE_TTL then
        return cachedVisibleWindows
    end
    
    -- 更新缓存，增强错误处理
    local success, windows = pcall(function()
        return hs.window.visibleWindows()
    end)
    
    if success and windows then
        -- 过滤掉无效窗口，减少后续错误
        local validWindows = {}
        for _, window in pairs(windows) do
            local success, isValid = pcall(function()
                return window and window:id() and window:isVisible()
            end)
            if success and isValid then
                table.insert(validWindows, window)
            end
        end
        cachedVisibleWindows = validWindows
        lastWindowCacheTime = currentTime
    else
        -- 如果获取失败，返回空表而不是旧缓存
        cachedVisibleWindows = {}
    end
    
    return cachedVisibleWindows
end

-- 清理过期的窗口状态记录（更积极的清理策略）
local function cleanupWindowStates()
    local currentTime = os.time()
    local activeWindowIds = {}
    
    -- 获取当前所有活跃窗口的ID集合
    for _, window in pairs(getVisibleWindowsCached()) do
        if window and window:id() then
            local windowId = getWindowId(window)
            if windowId then
                activeWindowIds[windowId] = true
            end
        end
    end
    
    -- 清理不再活跃的窗口状态（更积极）
    for windowId, state in pairs(windowStates) do
        -- 如果窗口不再活跃，或超过30秒未更新，则清理
        if not activeWindowIds[windowId] or (currentTime - state.lastCheck > 30) then
            windowStates[windowId] = nil
        end
    end
    
    -- 清理过期的顽固窗口记录
    for windowId, blacklistTime in pairs(stubbornWindows) do
        if not activeWindowIds[windowId] or (currentTime - blacklistTime > STUBBORN_WINDOW_TIMEOUT) then
            stubbornWindows[windowId] = nil
            stubbornWindowCounters[windowId] = nil -- 同时清理计数器
        end
    end
    
    -- 限制缓存大小，防止内存泄漏
    local count = 0
    for _ in pairs(windowStates) do count = count + 1 end
    if count > 100 then
        -- 如果缓存过大，保留最近的50个记录
        local sortedStates = {}
        for id, state in pairs(windowStates) do
            table.insert(sortedStates, {id = id, lastCheck = state.lastCheck})
        end
        table.sort(sortedStates, function(a, b) return a.lastCheck > b.lastCheck end)
        
        windowStates = {}
        for i = 1, 50 do
            if sortedStates[i] then
                windowStates[sortedStates[i].id] = {
                    isFullscreen = false,
                    lastCheck = sortedStates[i].lastCheck
                }
            end
        end
    end
    
    -- 同时清理全屏日志记录
    local visibleWindowIds = {}
    for _, window in pairs(getVisibleWindowsCached()) do
        if window and window:id() then
            visibleWindowIds[window:id()] = true
        end
    end
    
    -- 清理已经不存在的窗口日志记录
    for windowId, _ in pairs(fullscreenLoggedWindows) do
        if not visibleWindowIds[windowId] then
            fullscreenLoggedWindows[windowId] = nil
        end
    end
    
    -- 限制全屏日志缓存大小
    local logCount = 0
    for _ in pairs(fullscreenLoggedWindows) do logCount = logCount + 1 end
    if logCount > 50 then
        -- 清空过大的缓存
        fullscreenLoggedWindows = {}
    end
end

-- 初始化屏幕边界缓存（包含全屏检测所需信息）
local function updateScreenBoundaries()
    screenBoundaries = {}
    for _, screen in pairs(hs.screen.allScreens()) do
        local normalFrame = screen:frame()      -- 可用屏幕区域
        local fullFrame = screen:fullFrame()    -- 完整屏幕区域（包含菜单栏/notch）
        
        screenBoundaries[screen:id()] = {
            bottomLimit = normalFrame.y + normalFrame.h - WindowBoundaryMonitor.BOUNDARY_HEIGHT,
            screenFrame = normalFrame,    -- 保持向后兼容
            fullFrame = fullFrame,        -- 新增：用于全屏检测
            normalFrame = normalFrame,    -- 新增：明确标识
            name = screen:name(),
            isPrimary = screen == hs.screen.primaryScreen()
        }
    end
    -- 为兼容 Lua 对稀疏数组计数的不确定性，改用手动计数
    local screenCount = 0
    for _ in pairs(screenBoundaries) do screenCount = screenCount + 1 end
    print("更新屏幕边界缓存（含全屏检测信息），共" .. screenCount .. "个显示器")
end

-- 智能排除系统 - 检查是否应该排除某个窗口
local function shouldExcludeWindow(window)
    if not window then return true end
    
    local success, isValid = pcall(function()
        return window:isVisible() and window:isStandard()
    end)
    if not success or not isValid then
        return true
    end
    
    local app, appName = safeGetWindowApp(window)
    if not app or not appName then return true end
    
    local windowTitle = ""
    local titleSuccess, title = pcall(function()
        return window:title() or ""
    end)
    if titleSuccess then
        windowTitle = title
    end
    
    -- 基于应用名称的排除
    if excludedAppsSet[appName] then return true end
    
    -- 基于窗口标题的排除（浮动面板等）
    local floatingTitles = {
        "Palette", "Inspector", "Console", "Debugger", "调色板", "检查器"
    }
    for _, pattern in ipairs(floatingTitles) do
        if windowTitle:match(pattern) then return true end
    end
    
    -- 全屏窗口排除（防止死循环）
    if isWindowFullscreen(window) then
        -- 日志已在 isWindowFullscreen 中处理，避免重复
        return true
    end
    
    -- 基于尺寸的排除（微小的工具窗口）
    local frame = window:frame()
    -- 同时满足宽窄且矮小才排除，避免误伤纵向侧边栏等窄但高的窗口
    if frame.w < 200 and frame.h < 100 then return true end
    
    return false
end

-- 检查窗口是否违反底部边界（增加容差机制）
local function isWindowViolatingBoundary(window)
    if shouldExcludeWindow(window) then
        return false
    end
    
    local windowId = getWindowId(window)
    if not windowId then return false end
    
    -- 检查是否为顽固窗口
    local currentTime = os.time()
    if stubbornWindows[windowId] then
        local timeout = STUBBORN_WINDOW_TIMEOUT
        -- 如果失败次数达到上限，使用长期超时
        if stubbornWindowCounters[windowId] and stubbornWindowCounters[windowId] >= MAX_STUBBORN_ATTEMPTS then
            timeout = LONG_STUBBORN_TIMEOUT
        end
        if (currentTime - stubbornWindows[windowId]) < timeout then
            return false -- 黑名单内不处理
        end
    end
    
    local success, windowFrame = pcall(function()
        return window:frame()
    end)
    if not success or not windowFrame then return false end
    
    local screen = window:screen()
    if not screen then return false end
    
    local screenId = screen:id()
    local bounds = screenBoundaries[screenId]
    if not bounds then return false end
    
    -- 检查窗口底部边缘是否超出边界（添加3像素容差）
    local windowBottom = windowFrame.y + windowFrame.h
    local tolerance = 3  -- 3像素容差，避免微小偏差触发调整
    return windowBottom > (bounds.bottomLimit + tolerance)
end

-- 改进的窗口边界调整算法：智能处理顶部和底部边界违规
local function fixWindowBounds(window)
    local windowId = getWindowId(window)
    if not windowId then return end
    
    local success, windowFrame = pcall(function()
        return window:frame()
    end)
    if not success or not windowFrame then return end
    
    local screen = window:screen()
    if not screen then return end
    
    local bounds = screenBoundaries[screen:id()]
    if not bounds then return end
    
    local screenFrame = bounds.screenFrame
    local maxAllowedBottom = bounds.bottomLimit
    local minHeight = WindowBoundaryMonitor.config.MIN_WINDOW_HEIGHT
    
    -- 计算新的窗口框架
    local newFrame = {
        x = windowFrame.x,
        y = windowFrame.y,
        w = windowFrame.w,
        h = windowFrame.h
    }
    
    local windowBottom = windowFrame.y + windowFrame.h
    local needsAdjustment = false
    
    -- 情况1：窗口底部超出边界
    if windowBottom > maxAllowedBottom then
        -- 首先尝试缩减高度
        local newHeight = maxAllowedBottom - windowFrame.y
        
        if newHeight >= minHeight then
            -- 高度足够，只需缩减
            newFrame.h = newHeight
            needsAdjustment = true
        else
            -- 高度不够，需要上移窗口
            newFrame.y = maxAllowedBottom - minHeight
            newFrame.h = minHeight
            needsAdjustment = true
        end
    end
    
    -- 情况2：窗口顶部超出屏幕顶边界（额外保护）
    if newFrame.y < screenFrame.y then
        newFrame.y = screenFrame.y
        -- 重新计算高度以确保不超出底部边界
        local maxPossibleHeight = maxAllowedBottom - screenFrame.y
        newFrame.h = math.min(newFrame.h, maxPossibleHeight)
        needsAdjustment = true
    end
    
    -- 情况3：调整后窗口底部仍超出边界（最终检查）
    if newFrame.y + newFrame.h > maxAllowedBottom then
        newFrame.h = maxAllowedBottom - newFrame.y
        needsAdjustment = true
    end
    
    -- 确保最小高度
    if newFrame.h < minHeight then
        newFrame.h = minHeight
        -- 如果最小高度仍会超出边界，优先保证不超出边界
        if newFrame.y + newFrame.h > maxAllowedBottom then
            newFrame.y = maxAllowedBottom - minHeight
        end
        needsAdjustment = true
    end
    
    -- 应用调整
    if needsAdjustment then
        local currentTime = os.time()
        
        -- 设置带平滑动画的新框架
        local setSuccess = pcall(function()
            window:setFrame(newFrame, 0.2)
        end)
        
        if setSuccess then
            -- 显示详细的调整信息，使用安全的应用获取方法
            local app, appName = safeGetWindowApp(window)
            local displayName = appName or "未知应用"
            local adjustment = string.format("位置:%.0f→%.0f 高度:%.0f→%.0f", 
                windowFrame.y, newFrame.y, windowFrame.h, newFrame.h)
            print(string.format("已调整 %s 窗口 (%s) 以符合边界要求", displayName, adjustment))
            
            -- 短暂延迟后验证调整是否生效
            hs.timer.doAfter(0.5, function()
                local verifySuccess, newActualFrame = pcall(function()
                    return window:frame()
                end)
                
                if verifySuccess and newActualFrame then
                    local actualBottom = newActualFrame.y + newActualFrame.h
                    local tolerance = 5  -- 验证时使用稍大的容差
                    
                    -- 如果调整后仍然违规，标记为顽固窗口
                    if actualBottom > (bounds.bottomLimit + tolerance) then
                        -- 增加失败计数
                        stubbornWindowCounters[windowId] = (stubbornWindowCounters[windowId] or 0) + 1
                        stubbornWindows[windowId] = currentTime
                        
                        local attemptCount = stubbornWindowCounters[windowId]
                        if attemptCount >= MAX_STUBBORN_ATTEMPTS then
                            print(string.format("警告: %s 窗口调整连续 %d 次无效，已加入长期黑名单 (1小时)", displayName, attemptCount))
                        else
                            print(string.format("警告: %s 窗口调整无效，已加入临时黑名单 (第 %d/%d 次尝试)", displayName, attemptCount, MAX_STUBBORN_ATTEMPTS))
                        end
                    else
                        -- 调整成功，重置计数器
                        stubbornWindowCounters[windowId] = nil
                    end
                end
            end)
        else
            -- 如果设置框架失败，标记为顽固窗口
            stubbornWindows[windowId] = currentTime
        end
    end
end

-- 检查所有可见窗口
local function checkAllWindows()
    -- 定期清理窗口状态缓存
    cleanupWindowStates()
    
    local processedCount = 0
    local fullscreenExitCount = 0
    
    -- 使用缓存的窗口列表
    local visibleWindows = getVisibleWindowsCached()
    
    for _, window in pairs(visibleWindows) do
        -- 为每个窗口添加错误处理，防止单个窗口问题影响整个循环
        pcall(function()
            -- 更新窗口状态并检测是否从全屏退出
            local justExitedFullscreen = updateWindowState(window)
            
            if justExitedFullscreen then
                fullscreenExitCount = fullscreenExitCount + 1
                local app, appName = safeGetWindowApp(window)
                local displayName = appName or "未知应用"
                print(string.format("检测到 %s 退出全屏，重新检查边界", displayName))
                -- 清除全屏日志记录，以便下次进入全屏时可以再次记录
                local windowId = window:id()
                if windowId and fullscreenLoggedWindows[windowId] then
                    fullscreenLoggedWindows[windowId] = nil
                end
            end
            
            -- 检查边界违规并处理
            if isWindowViolatingBoundary(window) then
                fixWindowBounds(window)
                processedCount = processedCount + 1
            end
        end)
    end
    
    if processedCount > 0 then
        print(string.format("处理了 %d 个违规窗口", processedCount))
    end
    
    if fullscreenExitCount > 0 then
        print(string.format("检测到 %d 个窗口退出全屏状态", fullscreenExitCount))
    end
end

-- 屏幕监视器用于显示配置变更（增加防抖机制）
local screenWatcher = hs.screen.watcher.new(function()
    -- 取消之前的防抖定时器
    if screenChangeDebounceTimer then
        screenChangeDebounceTimer:stop()
        screenChangeDebounceTimer = nil
    end
    
    -- 设置新的防抖定时器，500ms内的多次变更只处理一次
    screenChangeDebounceTimer = hs.timer.doAfter(0.5, function()
        -- 只在必要时打印日志（减少噪音）
        local currentScreenCount = #hs.screen.allScreens()
        local oldScreenCount = 0
        for _ in pairs(screenBoundaries) do oldScreenCount = oldScreenCount + 1 end
        
        if currentScreenCount ~= oldScreenCount then
            print("检测到显示器配置变更，正在更新边界...")
        end
        
        updateScreenBoundaries()

        -- 清理顽固窗口黑名单，因为屏幕变化后布局可能已改变
        stubbornWindows = {}
        stubbornWindowCounters = {}
        print("已清理顽固窗口黑名单以应对显示器变更")
        
        -- 屏幕变更后重新检查所有可见窗口
        hs.timer.doAfter(WindowBoundaryMonitor.config.SCREEN_CHANGE_DELAY, function()
            checkAllWindows()
        end)
        
        screenChangeDebounceTimer = nil
    end)
end)

-- 初始化函数
function WindowBoundaryMonitor.start()
    -- 禁用窗口动画以获得快速响应
    hs.window.animationDuration = 0
    
    -- 初始化屏幕边界
    updateScreenBoundaries()
    
    -- 开始监控
    screenWatcher:start()
    
    -- 启动定时检查（确保清理旧定时器）
    if checkTimer then
        checkTimer:stop()
        checkTimer = nil
    end
    checkTimer = hs.timer.doEvery(WindowBoundaryMonitor.config.WINDOW_CHECK_INTERVAL, function()
        -- 使用 pcall 包装，防止单次错误中断定时器
        local success, err = pcall(checkAllWindows)
        if not success then
            print("窗口检查出错: " .. tostring(err))
        end
        
        -- 定期执行垃圾回收（每10次检查执行一次）
        if math.random(1, 10) == 1 then
            collectgarbage("collect")
        end
    end)
    
    -- 检查现有窗口
    checkAllWindows()
    
    print("窗口边界监控已启动（定时检查模式）")
    hs.alert.show("窗口边界监控已启动", 2)
end

-- 清理函数（增强的资源清理）
function WindowBoundaryMonitor.stop()
    if screenWatcher then 
        screenWatcher:stop()
        screenWatcher = nil
    end
    if checkTimer then
        checkTimer:stop()
        checkTimer = nil
    end
    if pathWatcher then
        pathWatcher:stop()
        pathWatcher = nil
    end
    
    -- 清理所有缓存和定时器
    windowStates = {}
    fullscreenLoggedWindows = {}
    cachedVisibleWindows = {}
    screenBoundaries = {}
    stubbornWindows = {}
    
    -- 清理防抖定时器
    if screenChangeDebounceTimer then
        screenChangeDebounceTimer:stop()
        screenChangeDebounceTimer = nil
    end
    
    -- 强制垃圾回收
    collectgarbage("collect")
    
    print("窗口边界监控已停止（已清理所有资源）")
    hs.alert.show("窗口边界监控已停止", 2)
end

-- 配置函数
function WindowBoundaryMonitor.addExcludedApp(appName)
    if not excludedAppsSet[appName] then
        table.insert(WindowBoundaryMonitor.excludedApps, appName)
        excludedAppsSet[appName] = true
        print("已添加排除应用: " .. appName)
    end
end

function WindowBoundaryMonitor.removeExcludedApp(appName)
    if excludedAppsSet[appName] then
        excludedAppsSet[appName] = nil
        for i, name in ipairs(WindowBoundaryMonitor.excludedApps) do
            if name == appName then
                table.remove(WindowBoundaryMonitor.excludedApps, i)
                break
            end
        end
        print("已移除排除应用: " .. appName)
    end
end

function WindowBoundaryMonitor.setBoundaryHeight(height)
    if height > 0 and height <= 200 then
        WindowBoundaryMonitor.BOUNDARY_HEIGHT = height
        updateScreenBoundaries()
        print(string.format("边界高度已设置为 %d 像素", height))
    else
        print("错误：边界高度必须在 1-200 像素之间")
    end
end

function WindowBoundaryMonitor.showStatus()
    local screenFrame = hs.screen.primaryScreen():frame()
    
    -- 计算缓存大小
    local windowStateCount = 0
    for _ in pairs(windowStates) do windowStateCount = windowStateCount + 1 end
    
    local fullscreenLogCount = 0
    for _ in pairs(fullscreenLoggedWindows) do fullscreenLogCount = fullscreenLogCount + 1 end
    
    local stubbornCount = 0
    for _ in pairs(stubbornWindows) do stubbornCount = stubbornCount + 1 end
    
    local screenCount = 0
    for _ in pairs(screenBoundaries) do screenCount = screenCount + 1 end
    
    -- 获取内存使用情况
    local memoryBefore = collectgarbage("count")
    collectgarbage("collect")
    local memoryAfter = collectgarbage("count")
    
    local status = string.format([[
窗口边界监控状态:
- 边界高度: %d 像素  
- 监控模式: 定时检查 (每%.1f秒)
- 屏幕尺寸: %dx%d
- 保护区域: 底部 %d 像素 (为 MiniMeters 预留)
- 排除的应用数量: %d

缓存状态:
- 窗口状态缓存: %d 条记录
- 全屏日志缓存: %d 条记录
- 调整冷却缓存: 0 条记录 (已移除)
- 顽固窗口黑名单: %d 条记录
- 屏幕边界缓存: %d 个屏幕
- 内存使用 (回收前): %.2f KB
- 内存使用 (回收后): %.2f KB
]], 
        WindowBoundaryMonitor.config.BOUNDARY_HEIGHT,
        WindowBoundaryMonitor.config.WINDOW_CHECK_INTERVAL,
        screenFrame.w, screenFrame.h,
        WindowBoundaryMonitor.config.BOUNDARY_HEIGHT,
        #WindowBoundaryMonitor.excludedApps,
        windowStateCount,
        fullscreenLogCount,
        0, -- cooldownCount is removed
        stubbornCount,
        screenCount,
        memoryBefore,
        memoryAfter
    )
    print(status)
    return status
end

-- 手动检查当前所有窗口
function WindowBoundaryMonitor.checkAllWindows()
    checkAllWindows()
end

-- 清理函数，在配置重载时调用
local function cleanup()
    WindowBoundaryMonitor.stop()
end

-- 注册清理处理器（避免重复创建）
if hs.configdir and not pathWatcher then
    pathWatcher = hs.pathwatcher.new(hs.configdir, cleanup)
    pathWatcher:start()
end

-- 清理所有缓存（手动调用）
function WindowBoundaryMonitor.clearCaches()
    -- 清空所有缓存
    windowStates = {}
    fullscreenLoggedWindows = {}
    cachedVisibleWindows = {}
    stubbornWindows = {}
    lastWindowCacheTime = 0
    
    -- 强制垃圾回收
    collectgarbage("collect")
    
    print("已清理所有缓存并执行垃圾回收")
    hs.alert.show("缓存已清理", 1)
end

-- 导出模块以供手动控制
return WindowBoundaryMonitor