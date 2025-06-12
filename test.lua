-- 窗口边界监控器测试脚本
-- 用于验证功能是否正常工作

local WindowBoundaryMonitor = require("window_boundary_monitor")

print("开始测试窗口边界监控器...")

-- 测试1: 基本功能测试
print("\n=== 测试1: 基本功能测试 ===")
WindowBoundaryMonitor.start()
hs.timer.doAfter(2, function()
    WindowBoundaryMonitor.showStatus()
end)

-- 测试2: 配置功能测试  
print("\n=== 测试2: 配置功能测试 ===")
hs.timer.doAfter(3, function()
    print("原始边界高度:", WindowBoundaryMonitor.BOUNDARY_HEIGHT)
    WindowBoundaryMonitor.setBoundaryHeight(50)
    print("修改后边界高度:", WindowBoundaryMonitor.BOUNDARY_HEIGHT)
    
    WindowBoundaryMonitor.addExcludedApp("Test App")
    print("添加排除应用完成")
    
    print("监控模式: 定时检查 (每2秒)")
    WindowBoundaryMonitor.showStatus()
end)

-- 测试3: 手动窗口检查
print("\n=== 测试3: 手动窗口检查 ===")
hs.timer.doAfter(5, function()
    print("执行手动窗口检查...")
    WindowBoundaryMonitor.checkAllWindows()
end)

-- 测试4: 屏幕信息检查
print("\n=== 测试4: 屏幕信息检查 ===")
hs.timer.doAfter(6, function()
    local screens = hs.screen.allScreens()
    print("检测到", #screens, "个显示器:")
    
    for i, screen in ipairs(screens) do
        local frame = screen:frame()
        local name = screen:name()
        local isPrimary = screen == hs.screen.primaryScreen()
        
        print(string.format("  显示器%d: %s %s", i, name, isPrimary and "(主显示器)" or ""))
        print(string.format("    尺寸: %dx%d", frame.w, frame.h))
        print(string.format("    位置: (%d, %d)", frame.x, frame.y))
        print(string.format("    底部边界: %d", frame.y + frame.h - WindowBoundaryMonitor.BOUNDARY_HEIGHT))
    end
end)

-- 测试5: 当前窗口信息
print("\n=== 测试5: 当前窗口信息 ===")
hs.timer.doAfter(7, function()
    local windows = hs.window.visibleWindows()
    print("当前可见窗口数量:", #windows)
    
    for i, window in ipairs(windows) do
        if i <= 5 then -- 只显示前5个窗口避免输出过多
            local app = window:application()
            local appName = app and app:name() or "未知应用"
            local title = window:title() or "无标题"
            local frame = window:frame()
            
            print(string.format("  窗口%d: %s - %s", i, appName, title))
            print(string.format("    位置: (%d, %d)", frame.x, frame.y))
            print(string.format("    尺寸: %dx%d", frame.w, frame.h))
            print(string.format("    底部位置: %d", frame.y + frame.h))
        end
    end
    
    if #windows > 5 then
        print(string.format("  ...还有 %d 个窗口未显示", #windows - 5))
    end
end)

print("\n测试将在8秒后完成...")
hs.timer.doAfter(8, function()
    print("\n=== 测试完成 ===")
    print("如果所有信息都正确显示，说明脚本工作正常")
    print("现在可以开始正常使用窗口边界监控功能")
end)