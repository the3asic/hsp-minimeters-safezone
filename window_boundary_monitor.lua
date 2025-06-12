-- Window Boundary Monitor  
-- 专为单显示器环境下与 MiniMeters 协同工作的窗口边界监控器
-- 优雅地为 MiniMeters 让出屏幕底部 32 像素空间
-- 若在非 Hammerspoon 环境执行，立即终止（提高鲁棒性）
if type(hs) ~= "table" then
    error("WindowBoundaryMonitor 必须在 Hammerspoon 环境中运行")
end

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

-- 缓存 MiniMeters 所在的显示器
local miniMetersScreen = nil

-- 定时器用于周期检查
local checkTimer = nil

-- 检测 MiniMeters 进程是否运行
local function isMiniMetersRunning()
    -- 方法1: 通过 hs.application.find 检测
    local miniMetersApp = hs.application.find("MiniMeters")
    if miniMetersApp then
        return true
    end
    
    -- 方法2: 通过进程名检测（备用方案）
    local output, status = hs.execute("pgrep -x MiniMeters")
    return status == true and output and output:match("%d+")
end

-- 检测 MiniMeters 应用所在的显示器
local function detectMiniMetersScreen()
    -- 首先检查进程是否存在
    if not isMiniMetersRunning() then
        return nil
    end
    
    local miniMetersApp = hs.application.find("MiniMeters")
    if not miniMetersApp then
        return nil
    end
    
    local windows = miniMetersApp:allWindows()
    if #windows == 0 then
        return nil
    end
    
    -- 获取主窗口（通常是第一个可见的标准窗口）
    for _, window in ipairs(windows) do
        if window:isVisible() and window:isStandard() then
            return window:screen()
        end
    end
    
    return nil
end

-- 更新 MiniMeters 显示器缓存
local function updateMiniMetersScreen()
    local newScreen = detectMiniMetersScreen()
    local oldScreenId = miniMetersScreen and miniMetersScreen:id() or nil
    local newScreenId = newScreen and newScreen:id() or nil
    
    if oldScreenId ~= newScreenId then
        miniMetersScreen = newScreen
        if newScreen then
            print("✓ MiniMeters 进程检测: 运行中，位于显示器 '" .. newScreen:name() .. "'")
        else
            if isMiniMetersRunning() then
                print("⚠ MiniMeters 进程检测: 运行中，但窗口不可见")
            else
                print("✗ MiniMeters 进程检测: 未运行，停止边界保护")
            end
        end
        return true  -- 发生了变化
    end
    
    return false  -- 没有变化
end

-- 初始化屏幕边界缓存（仅为 MiniMeters 所在显示器）
local function updateScreenBoundaries()
    screenBoundaries = {}
    
    -- 更新 MiniMeters 显示器信息
    updateMiniMetersScreen()
    
    -- 只为 MiniMeters 所在的显示器设置边界保护
    if miniMetersScreen then
        local frame = miniMetersScreen:frame()
        screenBoundaries[miniMetersScreen:id()] = {
            bottomLimit = frame.y + frame.h - WindowBoundaryMonitor.BOUNDARY_HEIGHT,
            screenFrame = frame,
            name = miniMetersScreen:name(),
            isPrimary = miniMetersScreen == hs.screen.primaryScreen()
        }
        print("设置边界保护 - 显示器: " .. miniMetersScreen:name() .. " (底部 " .. WindowBoundaryMonitor.BOUNDARY_HEIGHT .. "px)")
    else
        print("未检测到 MiniMeters，跳过边界保护设置")
    end
    
    -- 显示所有显示器信息（调试用）
    local allScreens = hs.screen.allScreens()
    local screenCount = #allScreens
    print("系统共有 " .. screenCount .. " 个显示器，保护其中 " .. (miniMetersScreen and 1 or 0) .. " 个")
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
    
    -- 多显示器支持：只检查 MiniMeters 所在显示器的窗口
    if not miniMetersScreen or screen:id() ~= miniMetersScreen:id() then
        return false  -- 不是 MiniMeters 所在显示器，跳过检查
    end
    
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
    local MIN_HEIGHT = 100

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

-- 检查所有可见窗口 (多显示器支持版本)
-- 核心逻辑: 只监控 MiniMeters 所在显示器的窗口
local function checkAllWindows()
    -- Step 1: 定期检查 MiniMeters 位置是否改变
    -- 这包括: 进程启动/终止、窗口移动到其他显示器、窗口可见性变化
    local miniMetersChanged = updateMiniMetersScreen()
    if miniMetersChanged then
        -- MiniMeters 位置发生变化，重新计算边界保护区域
        updateScreenBoundaries()
    end
    
    -- Step 2: 进程验证 - 如果 MiniMeters 不存在，完全跳过监控
    -- 这确保了无 MiniMeters 时零性能开销
    if not miniMetersScreen then
        return  -- 提前返回，不处理任何窗口
    end
    
    -- Step 3: 窗口处理 - 仅检查当前所有可见窗口
    -- 但在 isWindowViolatingBoundary() 中会进一步过滤到目标显示器
    local processedCount = 0
    for _, window in pairs(hs.window.visibleWindows()) do
        if isWindowViolatingBoundary(window) then
            fixWindowBounds(window)
            processedCount = processedCount + 1
        end
    end
    
    -- Step 4: 反馈 - 仅在实际处理窗口时输出日志
    if processedCount > 0 then
        print(string.format("在显示器 '%s' 上处理了 %d 个违规窗口", miniMetersScreen:name(), processedCount))
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
    local allScreens = hs.screen.allScreens()
    local totalScreens = #allScreens
    
    local status = string.format([[
窗口边界监控状态 (多显示器支持):
- 边界高度: %d 像素  
- 监控模式: 定时检查 (每2秒)
- 系统显示器总数: %d
- MiniMeters 显示器: %s
- 保护状态: %s
- 排除的应用数量: %d
]], 
        WindowBoundaryMonitor.BOUNDARY_HEIGHT,
        totalScreens,
        miniMetersScreen and (miniMetersScreen:name() .. " (" .. miniMetersScreen:frame().w .. "x" .. miniMetersScreen:frame().h .. ")") or "未检测到",
        miniMetersScreen and ("保护 " .. miniMetersScreen:name() .. " 底部 " .. WindowBoundaryMonitor.BOUNDARY_HEIGHT .. "px") or "无保护区域",
        #WindowBoundaryMonitor.excludedApps
    )
    
    -- 显示所有显示器信息
    if totalScreens > 1 then
        status = status .. "\n所有显示器列表:\n"
        for i, screen in ipairs(allScreens) do
            local frame = screen:frame()
            local isActive = miniMetersScreen and screen:id() == miniMetersScreen:id()
            status = status .. string.format("  %d. %s (%dx%d) %s\n", 
                i, screen:name(), frame.w, frame.h, 
                isActive and "[活动保护]" or "[未监控]"
            )
        end
    end
    
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