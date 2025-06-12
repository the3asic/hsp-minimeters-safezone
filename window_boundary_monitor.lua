-- Window Boundary Monitor  
-- 专为单显示器环境下与 MiniMeters 协同工作的窗口边界监控器
-- 优雅地为 MiniMeters 让出屏幕底部 32 像素空间

local WindowBoundaryMonitor = {}

-- 边界高度设置 (像素)
-- 要修改边界高度，请更改下面的数值，然后重新加载 Hammerspoon 配置
-- 推荐值: 32 (适配 MiniMeters 默认高度)
WindowBoundaryMonitor.BOUNDARY_HEIGHT = 32

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

-- 定时器用于周期检查
local checkTimer = nil

-- 初始化屏幕边界缓存
local function updateScreenBoundaries()
    screenBoundaries = {}
    for _, screen in pairs(hs.screen.allScreens()) do
        local frame = screen:frame()
        screenBoundaries[screen:id()] = {
            bottomLimit = frame.y + frame.h - WindowBoundaryMonitor.BOUNDARY_HEIGHT,
            screenFrame = frame,
            name = screen:name(),
            isPrimary = screen == hs.screen.primaryScreen()
        }
    end
    print("更新屏幕边界缓存，共" .. #hs.screen.allScreens() .. "个显示器")
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
    
    -- 基于尺寸的排除（微小的工具窗口）
    local frame = window:frame()
    if frame.w < 200 or frame.h < 100 then return true end
    
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
    
    -- 确保最小窗口高度
    local MIN_HEIGHT = 100
    if newHeight < MIN_HEIGHT then
        -- 如果窗口在屏幕上位置过高，将其向下移动
        windowFrame.y = maxAllowedBottom - MIN_HEIGHT
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
    local processedCount = 0
    for _, window in pairs(hs.window.visibleWindows()) do
        if isWindowViolatingBoundary(window) then
            fixWindowBounds(window)
            processedCount = processedCount + 1
        end
    end
    if processedCount > 0 then
        print(string.format("处理了 %d 个违规窗口", processedCount))
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
    checkTimer = hs.timer.doEvery(2, checkAllWindows)
    
    -- 检查现有窗口
    checkAllWindows()
    
    print("窗口边界监控已启动（定时检查模式）")
    hs.alert.show("窗口边界监控已启动", 2)
end

-- 清理函数
function WindowBoundaryMonitor.stop()
    if screenWatcher then 
        screenWatcher:stop() 
        screenWatcher = nil
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
- 监控模式: 定时检查 (每2秒)
- 屏幕尺寸: %dx%d
- 保护区域: 底部 %d 像素 (为 MiniMeters 预留)
- 排除的应用数量: %d
]], 
        WindowBoundaryMonitor.BOUNDARY_HEIGHT,
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