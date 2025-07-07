-- 性能测试脚本
-- 用于测试 window_boundary_monitor 的内存使用和性能

-- 加载模块
local wbm = require("window_boundary_monitor")

-- 开始测试
print("===== 开始性能测试 =====")
print(string.format("测试时间: %s", os.date()))

-- 1. 启动监控
print("\n1. 启动窗口边界监控...")
wbm.start()

-- 2. 显示初始状态
print("\n2. 初始状态:")
wbm.showStatus()

-- 3. 模拟长时间运行
print("\n3. 开始模拟长时间运行...")
print("每30秒显示一次状态，共运行5分钟")
print("您可以在此期间打开/关闭窗口，进入/退出全屏等操作")

local testDuration = 300  -- 5分钟
local checkInterval = 30   -- 每30秒检查一次
local startTime = os.time()

-- 定时器：每30秒显示状态
local statusTimer = hs.timer.doEvery(checkInterval, function()
    local elapsed = os.time() - startTime
    print(string.format("\n[%d秒后] 内存状态检查:", elapsed))
    
    -- 获取当前内存使用
    local memoryBefore = collectgarbage("count")
    
    -- 显示缓存状态
    local windowStateCount = 0
    for _ in pairs(wbm.windowStates or {}) do windowStateCount = windowStateCount + 1 end
    
    local fullscreenLogCount = 0
    for _ in pairs(wbm.fullscreenLoggedWindows or {}) do fullscreenLogCount = fullscreenLogCount + 1 end
    
    print(string.format("- 内存使用: %.2f KB", memoryBefore))
    print(string.format("- 窗口状态缓存: %d 条", windowStateCount))
    print(string.format("- 全屏日志缓存: %d 条", fullscreenLogCount))
    
    -- 如果内存使用超过阈值，发出警告
    if memoryBefore > 10000 then  -- 10MB
        print("⚠️  警告：内存使用较高！")
    end
end)

-- 定时器：测试结束
hs.timer.doAfter(testDuration, function()
    print("\n===== 测试结束 =====")
    
    -- 停止状态检查
    statusTimer:stop()
    
    -- 显示最终状态
    print("\n最终状态:")
    wbm.showStatus()
    
    -- 手动触发缓存清理
    print("\n执行手动缓存清理...")
    wbm.clearCaches()
    
    -- 再次显示状态
    print("\n清理后状态:")
    wbm.showStatus()
    
    -- 停止监控
    print("\n停止窗口边界监控...")
    wbm.stop()
    
    print("\n测试完成！")
    print("如果内存使用稳定且缓存大小合理，说明修复有效。")
end)

print("\n提示：")
print("- 测试期间请正常使用电脑，打开/关闭窗口")
print("- 特别是频繁进入/退出全屏模式")
print("- 观察内存使用和缓存大小是否持续增长")
print("- 如需提前结束测试，在控制台输入: wbm.stop()")