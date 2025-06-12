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
    -- 定时检查间隔（秒）
    TIMER_INTERVAL   = 2,
    -- 全屏检测的像素容差
    FULLSCREEN_TOLERANCE = 2,
    -- 调整窗口时允许的最小高度
    MIN_HEIGHT = 100,
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
    
    ------------------------------------------------------------------
    -- 全屏检测：使用像素容差 + 百分比容差，兼容 HiDPI/缩放/刘海屏
    ------------------------------------------------------------------
    local pixTol = WindowBoundaryMonitor.config.FULLSCREEN_TOLERANCE or 2
    local pctTol = 0.01 -- 1% 额外比例容差

    -- 辅助函数：比较两个值是否在容差范围
    local function withinTol(a, b, dim)
        local diff = math.abs(a - b)
        return diff <= pixTol or diff <= dim * pctTol
    end

    -- 获取最新 fullFrame（菜单栏显隐时会变化）
    local dynamicFullFrame = screen:fullFrame()

    -- 是否几何覆盖（匹配 cached fullFrame 或 dynamic fullFrame 其一即可）
    local function frameMatches(targetFrame)
        return withinTol(windowFrame.x, targetFrame.x, targetFrame.w) and
               withinTol(windowFrame.y, targetFrame.y, targetFrame.h) and
               withinTol(windowFrame.w, targetFrame.w, targetFrame.w) and
               withinTol(windowFrame.h, targetFrame.h, targetFrame.h)
    end

    local matchesCachedFull  = frameMatches(fullFrame)
    local matchesDynamicFull = frameMatches(dynamicFullFrame)

    if matchesCachedFull or matchesDynamicFull then
        -- 视为全屏
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
        print(string.format("跳过真全屏窗口: %s", appName))
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

-- 通过调整高度修复窗口边界违规
local function fixWindowBounds(window)
    local windowFrame = window:frame()
    local screen = window:screen()
    if not screen then return end
    
    local bounds = screenBoundaries[screen:id()]
    if not bounds then return end
    
    -- 计算符合边界要求的新高度
    local maxAllowedBottom = bounds.bottomLimit
    local newHeight = maxAllowedBottom - windowFrame.y
    
    -- 最小窗口高度
    local MIN_HEIGHT = WindowBoundaryMonitor.config.MIN_HEIGHT

    -- 若窗口顶端已低于/超过底部限制，newHeight 为负，需要整体上移
    if newHeight <= 0 then
        windowFrame.y = maxAllowedBottom - MIN_HEIGHT
        newHeight = MIN_HEIGHT
    elseif newHeight < MIN_HEIGHT then
        newHeight = MIN_HEIGHT
    end
    
    -- 应用新尺寸
    local newFrame = {
        x = windowFrame.x,
        y = windowFrame.y,
        w = windowFrame.w,
        h = newHeight
    }
    
    -- 设置带简短动画的新框架
    window:setFrame(newFrame, 0.2)
    
    -- 显示简短通知
    local appName = window:application():name()
    print(string.format("已调整 %s 窗口尺寸以符合边界要求", appName))
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
    hs.timer.doAfter(1.0, function()
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
    
    -- 启动定时检查（每2秒检查一次）
    if checkTimer then
        checkTimer:stop()
    end
    checkTimer = hs.timer.doEvery(WindowBoundaryMonitor.config.TIMER_INTERVAL, checkAllWindows)
    
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
        WindowBoundaryMonitor.config.BOUNDARY_HEIGHT = height
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
- 监控模式: 定时检查 (每%d秒)
- 屏幕尺寸: %dx%d
- 保护区域: 底部 %d 像素 (为 MiniMeters 预留)
- 排除的应用数量: %d
]], 
        WindowBoundaryMonitor.BOUNDARY_HEIGHT,
        WindowBoundaryMonitor.config.TIMER_INTERVAL,
        screenFrame.w, screenFrame.h,
        WindowBoundaryMonitor.BOUNDARY_HEIGHT,
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