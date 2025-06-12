# Hammerspoon 窗口边界监控 - 最终部署指南

## 快速部署

### 1. 安装 Hammerspoon (如果尚未安装)
```bash
brew install --cask hammerspoon
```

### 2. 停止现有的 yabai/skhd 服务 (如果正在运行)
```bash
yabai --stop-service
skhd --stop-service
```

### 3. 部署配置文件
```bash
# 创建配置目录
mkdir -p ~/.hammerspoon

# 复制配置文件
cp window_boundary_monitor.lua ~/.hammerspoon/
cp init.lua ~/.hammerspoon/
```

### 4. 启动 Hammerspoon
```bash
open -a "Hammerspoon"
```

### 5. 配置权限
- 当 Hammerspoon 首次启动时，会要求辅助功能权限
- 前往 系统偏好设置 > 安全性与隐私 > 辅助功能
- 将 Hammerspoon 添加到允许的应用列表中

## 验证安装

### 检查运行状态
1. 看到 Hammerspoon 菜单栏图标
2. 控制台输出类似：
   ```
   正在加载 Hammerspoon 配置...
   更新屏幕边界缓存，共1个显示器
   窗口边界监控已启动（定时检查模式）
   ```

### 测试功能
1. 使用快捷键 `Cmd+Alt+Ctrl+W` 查看状态
2. 尝试将任意窗口拖拽到屏幕底部，观察是否自动调整

## 快捷键参考

| 快捷键 | 功能 |
|--------|------|
| `Cmd+Alt+Ctrl+W` | 显示监控状态 |
| `Cmd+Alt+Ctrl+R` | 手动检查所有窗口 |
| `Cmd+Alt+Ctrl+S` | 停止监控 |
| `Cmd+Alt+Ctrl+A` | 启动监控 |
| `Cmd+Alt+Ctrl+=` | 增加边界高度 (+8px) |
| `Cmd+Alt+Ctrl+-` | 减少边界高度 (-8px) |

## 应用启动快捷键配置 (Raycast)

在 Raycast 中配置以下快捷键：

| 快捷键 | 应用 |
|--------|------|
| `hyper + o` | Obsidian |
| `hyper + n` | Notion |
| `hyper + z` | Google Chrome |
| `hyper + w` | WeChat |
| `hyper + c` | ChatGPT |
| `hyper + t` | Warp |
| `hyper + m` | Monica |
| `hyper + \`` | AIBOI |
| `hyper + p` | Cursor |

## 高级配置

### 控制台命令
在 Hammerspoon 控制台中可以使用：

```lua
-- 查看状态
wbm.showStatus()

-- 调整边界高度
wbm.setBoundaryHeight(50)  -- 设置为50像素

-- 添加/移除排除应用
wbm.addExcludedApp("Visual Studio Code")
wbm.removeExcludedApp("Finder")

-- 手动检查
wbm.checkAllWindows()

-- 停止/启动
wbm.stop()
wbm.start()
```

### 自定义排除应用
编辑 `window_boundary_monitor.lua` 文件，修改 `excludedApps` 列表：

```lua
WindowBoundaryMonitor.excludedApps = {
    "System Preferences",
    "Finder",
    "Activity Monitor",
    "Console",
    "Hammerspoon",
    "System Information",
    "Keychain Access",
    -- 添加你想排除的应用
    "Your App Name"
}
```

## 故障排除

### 常见问题

1. **脚本不工作**
   - 确保 Hammerspoon 有辅助功能权限
   - 检查控制台是否有错误信息

2. **某些应用窗口不被处理**
   - 检查应用是否在排除列表中
   - 使用 `wbm.showStatus()` 查看配置

3. **性能问题**
   - 定时检查已优化为每2秒一次
   - 如需调整，修改 `checkTimer = hs.timer.doEvery(2, checkAllWindows)` 中的间隔

### 卸载

如果需要卸载：
```bash
# 停止 Hammerspoon
killall Hammerspoon

# 删除配置文件
rm -rf ~/.hammerspoon

# 卸载应用
brew uninstall --cask hammerspoon
```

## 与状态栏应用的兼容性

### Minimeters 兼容模式
- **启动 Hammerspoon** = 自动保留底部32像素空间
- **退出 Hammerspoon** = 取消空间保留，窗口可使用全屏

### 其他状态栏应用
如果你使用其他底部状态栏应用，可以：
1. 调整边界高度以匹配状态栏高度
2. 使用快捷键 `Cmd+Alt+Ctrl+=/-` 实时调整
3. 通过控制台命令精确设置：`wbm.setBoundaryHeight(你的高度)`

## 技术特性

- **监控模式**: 定时检查 (每2秒)
- **资源占用**: 极低，仅在发现违规时处理
- **多显示器**: 完全支持，每个显示器独立处理
- **兼容性**: 避免复杂事件订阅，确保稳定性
- **日志**: 最小化输出，仅在必要时显示信息

这个部署指南提供了完整的安装、配置和使用说明。如有问题，请查看 Hammerspoon 控制台输出或使用快捷键获取状态信息。