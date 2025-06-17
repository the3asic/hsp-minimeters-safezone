-- Window Boundary Monitor  
-- 专为单显示器环境下与 MiniMeters 协同工作的窗口边界监控器
-- 优雅地为 MiniMeters 让出屏幕底部 32 像素空间
-- 若在非 Hammerspoon 环境执行，立即终止（提高鲁棒性）
if type(hs) ~= "table" then
    error("WindowBoundaryMonitor 必须在 Hammerspoon 环境中运行")
end

local WindowBoundaryMonitor = {}

-- 统一配置表：集中所有可调常量，便于维护
WindowBoundaryMonitor.config = {
    -- 为 MiniMeters 预留的底部像素高度
    BOUNDARY_HEIGHT = 32,
    -- 窗口检查的定时器间隔（秒）
    WINDOW_CHECK_INTERVAL = 2,
    -- 屏幕变更后的延迟检查间隔（秒）
    SCREEN_CHANGE_DELAY = 1.0,
    -- 全屏检测的像素容差
    FULLSCREEN_TOLERANCE = 2,
    -- 窗口调整时保证的最小窗口高度
    MIN_WINDOW_HEIGHT = 100,
}

-- 为向后兼容保留旧字段（别名）
WindowBoundaryMonitor.BOUNDARY_HEIGHT = WindowBoundaryMonitor.config.BOUNDARY_HEIGHT

-- 排除应用列表 - 仅排除必要的应用
WindowBoundaryMonitor.excludedApps = {
    "Hammerspoon",    -- Hammerspoon 自身
    "MiniMeters"      -- MiniMeters 状态栏
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

-- 定时器用于周期检查
local checkTimer = nil

-- 检测窗口是否为真全屏状态（使用缓存的屏幕信息）
local function isWindowFullscreen(window)
    if not window then return false end
    
    local app = window:application()
    if not app then return false end
    
    local appName = app:name()
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

-- 获取窗口唯一标识
local function getWindowId(window)
    if not window then return nil end
    local app = window:application()
    if not app then return nil end
    return app:name() .. ":" .. (window:title() or "untitled")
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

-- 清理过期的窗口状态记录
local function cleanupWindowStates()
    local currentTime = os.time()
    for windowId, state in pairs(windowStates) do
        -- 清理超过5分钟的记录
        if currentTime - state.lastCheck > 300 then
            windowStates[windowId] = nil
        end
    end
    
    -- 同时清理全屏日志记录，当窗口不再是全屏时移除记录
    local visibleWindows = {}
    for _, window in pairs(hs.window.visibleWindows()) do
        if window and window:id() then
            visibleWindows[window:id()] = window
        end
    end
    
    -- 清理已经不存在或不再是全屏的窗口日志记录
    for windowId, _ in pairs(fullscreenLoggedWindows) do
        local window = visibleWindows[windowId]
        if not window or not isWindowFullscreen(window) then
            fullscreenLoggedWindows[windowId] = nil
        end
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
    if not window or not window:isVisible() or not window:isStandard() then
        return true
    end
    
    local app = window:application()
    if not app then return true end
    
    local appName = app:name()
    local windowTitle = window:title() or ""
    
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

-- 检查窗口是否违反底部边界
local function isWindowViolatingBoundary(window)
    if shouldExcludeWindow(window) then
        return false
    end
    
    local windowFrame = window:frame()
    local screen = window:screen()
    if not screen then return false end
    
    local screenId = screen:id()
    local bounds = screenBoundaries[screenId]
    if not bounds then return false end
    
    -- 检查窗口底部边缘是否超出边界
    local windowBottom = windowFrame.y + windowFrame.h
    return windowBottom > bounds.bottomLimit
end

-- 改进的窗口边界调整算法：智能处理顶部和底部边界违规
local function fixWindowBounds(window)
    local windowFrame = window:frame()
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
        -- 设置带平滑动画的新框架
        window:setFrame(newFrame, 0.2)
        
        -- 显示详细的调整信息
        local appName = window:application():name()
        local adjustment = string.format("位置:%.0f→%.0f 高度:%.0f→%.0f", 
            windowFrame.y, newFrame.y, windowFrame.h, newFrame.h)
        print(string.format("已调整 %s 窗口 (%s) 以符合边界要求", appName, adjustment))
    end
end

-- 检查所有可见窗口
local function checkAllWindows()
    -- 定期清理窗口状态缓存
    cleanupWindowStates()
    
    local processedCount = 0
    local fullscreenExitCount = 0
    
    for _, window in pairs(hs.window.visibleWindows()) do
        -- 更新窗口状态并检测是否从全屏退出
        local justExitedFullscreen = updateWindowState(window)
        
        if justExitedFullscreen then
            fullscreenExitCount = fullscreenExitCount + 1
            local appName = window:application() and window:application():name() or "未知应用"
            print(string.format("检测到 %s 退出全屏，重新检查边界", appName))
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
    end
    
    if processedCount > 0 then
        print(string.format("处理了 %d 个违规窗口", processedCount))
    end
    
    if fullscreenExitCount > 0 then
        print(string.format("检测到 %d 个窗口退出全屏状态", fullscreenExitCount))
    end
end

-- 屏幕监视器用于显示配置变更
local screenWatcher = hs.screen.watcher.new(function()
    print("检测到显示器配置变更，正在更新边界...")
    updateScreenBoundaries()
    
    -- 屏幕变更后重新检查所有可见窗口
    hs.timer.doAfter(WindowBoundaryMonitor.config.SCREEN_CHANGE_DELAY, function()
        checkAllWindows()
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
    
    -- 启动定时检查
    if checkTimer then
        checkTimer:stop()
    end
    checkTimer = hs.timer.doEvery(WindowBoundaryMonitor.config.WINDOW_CHECK_INTERVAL, checkAllWindows)
    
    -- 检查现有窗口
    checkAllWindows()
    
    print("窗口边界监控已启动（定时检查模式）")
    hs.alert.show("窗口边界监控已启动", 2)
end

-- 清理函数
function WindowBoundaryMonitor.stop()
    if screenWatcher then 
        -- 仅停止，不置空，避免重启时空引用
        screenWatcher:stop() 
    end
    if checkTimer then
        checkTimer:stop()
        checkTimer = nil
    end
    
    print("窗口边界监控已停止")
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
    local status = string.format([[
窗口边界监控状态:
- 边界高度: %d 像素  
- 监控模式: 定时检查 (每%.1f秒)
- 屏幕尺寸: %dx%d
- 保护区域: 底部 %d 像素 (为 MiniMeters 预留)
- 排除的应用数量: %d
]], 
        WindowBoundaryMonitor.config.BOUNDARY_HEIGHT,
        WindowBoundaryMonitor.config.WINDOW_CHECK_INTERVAL,
        screenFrame.w, screenFrame.h,
        WindowBoundaryMonitor.config.BOUNDARY_HEIGHT,
        #WindowBoundaryMonitor.excludedApps
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

-- 注册清理处理器
if hs.configdir then
    hs.pathwatcher.new(hs.configdir, cleanup):start()
end

-- 导出模块以供手动控制
return WindowBoundaryMonitor