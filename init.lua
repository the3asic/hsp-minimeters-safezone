-- Hammerspoon 初始化脚本
-- 窗口边界监控主配置文件 (定时检查版本)

print("正在加载 Hammerspoon 配置...")

-- 加载窗口边界监控模块
local WindowBoundaryMonitor = require("window_boundary_monitor")

-- 自动启动监控
WindowBoundaryMonitor.start()

-- 设置快捷键用于手动控制
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "W", function()
    WindowBoundaryMonitor.showStatus()
    hs.alert.show("状态已输出到控制台", 1)
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
    WindowBoundaryMonitor.checkAllWindows()
    hs.alert.show("手动检查已完成", 1)
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "S", function()
    WindowBoundaryMonitor.stop()
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "A", function()
    WindowBoundaryMonitor.start()
end)

-- 添加边界高度调整快捷键
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "=", function()
    local current = WindowBoundaryMonitor.BOUNDARY_HEIGHT
    WindowBoundaryMonitor.setBoundaryHeight(current + 8)
    hs.alert.show(string.format("边界高度: %d 像素", WindowBoundaryMonitor.BOUNDARY_HEIGHT), 1)
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "-", function()
    local current = WindowBoundaryMonitor.BOUNDARY_HEIGHT
    if current > 8 then
        WindowBoundaryMonitor.setBoundaryHeight(current - 8)
        hs.alert.show(string.format("边界高度: %d 像素", WindowBoundaryMonitor.BOUNDARY_HEIGHT), 1)
    end
end)

-- 全局变量供控制台使用
wbm = WindowBoundaryMonitor

print("Hammerspoon 配置加载完成")
print("快捷键:")
print("  Cmd+Alt+Ctrl+W: 显示状态")
print("  Cmd+Alt+Ctrl+R: 手动检查所有窗口")
print("  Cmd+Alt+Ctrl+S: 停止监控")
print("  Cmd+Alt+Ctrl+A: 启动监控")
print("  Cmd+Alt+Ctrl+=: 增加边界高度 (+8px)")
print("  Cmd+Alt+Ctrl+-: 减少边界高度 (-8px)")
print("控制台变量: wbm (WindowBoundaryMonitor)")
print("监控模式: 定时检查 (每2秒)")

-- 配置重载通知
hs.alert.show("窗口边界监控已加载", 2)