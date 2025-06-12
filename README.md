# Hammerspoon 窗口边界监控器

这是一个 Hammerspoon 脚本，用于自动防止窗口重叠 macOS 屏幕底部的 32 像素区域。该脚本提供稳定的定时监控、智能排除、多显示器支持等功能。

## 功能特点

- **定时监控**: 每2秒检查一次所有窗口，确保稳定性和兼容性
- **智能调整**: 自动调整违规窗口的高度，避免重叠底部区域
- **多显示器支持**: 完整支持多显示器设置，每个显示器独立处理
- **智能排除**: 排除系统应用、小窗口和特殊类型窗口
- **性能优化**: 轻量级定时检查，资源占用极低
- **可配置**: 支持自定义边界高度、排除应用列表等
- **实时调整**: 支持快捷键动态调整边界高度

## 安装和使用

### 1. 安装 Hammerspoon

如果还没有安装 Hammerspoon：

```bash
brew install --cask hammerspoon
```

### 2. 部署脚本

将这些文件复制到你的 Hammerspoon 配置目录：

```bash
# 创建 Hammerspoon 配置目录（如果不存在）
mkdir -p ~/.hammerspoon

# 复制脚本文件
cp init.lua ~/.hammerspoon/
cp window_boundary_monitor.lua ~/.hammerspoon/
```

### 3. 重载配置

打开 Hammerspoon 并重载配置，或使用快捷键 `Cmd+Alt+Ctrl+R` (如果 Hammerspoon 已运行)。

## 快捷键

- `Cmd+Alt+Ctrl+W`: 显示监控状态
- `Cmd+Alt+Ctrl+R`: 手动检查所有窗口
- `Cmd+Alt+Ctrl+S`: 停止监控
- `Cmd+Alt+Ctrl+A`: 启动监控
- `Cmd+Alt+Ctrl+=`: 增加边界高度 (+8像素)
- `Cmd+Alt+Ctrl+-`: 减少边界高度 (-8像素)

## 编程接口

脚本暴露了 `wbm` 全局变量，你可以在 Hammerspoon 控制台中使用：

```lua
-- 显示状态
wbm.showStatus()

-- 设置边界高度为 50 像素
wbm.setBoundaryHeight(50)

-- 添加排除应用
wbm.addExcludedApp("Visual Studio Code")

-- 移除排除应用
wbm.removeExcludedApp("Finder")

-- 手动检查所有窗口
wbm.checkAllWindows()

-- 停止/启动监控
wbm.stop()
wbm.start()
```

## 配置选项

### 默认排除的应用

```lua
{
    "System Preferences",
    "Finder", 
    "Activity Monitor",
    "Console",
    "Hammerspoon",
    "System Information",
    "Keychain Access"
}
```

### 边界高度

默认为 32 像素，可以通过 `setBoundaryHeight()` 函数修改（范围：1-200 像素）。

### 自动排除规则

脚本会自动排除以下类型的窗口：
- 不可见或非标准窗口
- 宽度小于 200 像素或高度小于 100 像素的窗口
- 标题包含 "Palette"、"Inspector"、"Console"、"Debugger" 等的窗口

## 技术实现

### 核心架构

- **定时检查**: 使用 `hs.timer.doEvery` 每2秒检查一次所有窗口
- **屏幕监控**: 使用 `hs.screen.watcher` 监听显示器配置变更
- **智能缓存**: 缓存屏幕边界信息，支持动态显示器配置
- **资源管理**: 正确的对象生命周期管理，防止内存泄漏

### 坐标系统

macOS 使用统一坐标网格，主显示器左上角为 (0,0)。脚本正确处理多显示器的复杂坐标变换。

### 性能优化

- 使用哈希表进行 O(1) 应用排除检查
- 定时检查机制避免事件订阅的复杂性和兼容性问题
- 智能过滤避免处理无关窗口
- 仅在发现违规窗口时才输出日志信息

## 故障排除

### 常见问题

1. **脚本不工作**: 确保 Hammerspoon 有辅助功能权限
2. **某些窗口不被处理**: 检查应用是否在排除列表中
3. **性能问题**: 调整防抖延迟或添加更多排除规则

### 调试

启用调试输出查看脚本运行状态：

```lua
-- 在 Hammerspoon 控制台中查看日志
print("当前监控状态:")
wbm.showStatus()
```

## 许可和贡献

这个脚本基于详细的 Hammerspoon API 分析和最佳实践开发。欢迎提出改进建议和bug报告。