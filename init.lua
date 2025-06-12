-- Hammerspoon 初始化脚本
-- 专为 MiniMeters 协同工作的极简窗口边界监控器

-- 加载窗口边界监控模块
local WindowBoundaryMonitor = require("window_boundary_monitor")

-- 自动启动监控（唯一功能）
WindowBoundaryMonitor.start()

-- 全局变量供控制台使用
wbm = WindowBoundaryMonitor

print("MiniMeters 窗口边界监控已启动")
print("控制台变量: wbm")
print("提示: 要停止监控请退出 Hammerspoon 应用")