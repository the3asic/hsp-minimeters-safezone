# Hammerspoon 窗口边界监控器

专为与 MiniMeters 状态栏应用协同工作的 Hammerspoon 脚本。智能为 MiniMeters 预留屏幕底部 32 像素空间，确保窗口最大化、分屏或拖拽时不会遮挡状态栏。

## ✨ 主要特性

- 🚀 **一键安装**：图形化安装程序，无需终端操作
- 🔄 **智能更新**：自动检测版本并提供更新
- 🎯 **专注功能**：仅专注窗口边界保护，极简稳定
- 🔧 **零配置**：安装即用，无需复杂设置
- 🗑️ **干净卸载**：完整的安装/更新/卸载支持

## 📦 项目文件

```text
hammerspoon/
├── installer.app                   # 🎯 图形化安装程序（推荐）
├── setup.sh                       # 🛠️ 命令行安装脚本
├── window_boundary_monitor.lua    # 💎 核心监控模块
├── init.lua                       # 🔧 Hammerspoon 初始化配置
├── MiniMeters-config.json         # 📋 MiniMeters 推荐配置参考
└── README.md                      # 📖 项目说明（本文件）
```

## 🚀 快速安装

### 方法一：图形化安装（推荐）

1. **下载项目**
   - 访问 [GitHub 发布页面](https://github.com/the3asic/hsp-minimeters-safezone/releases)
   - 下载最新版本的 ZIP 文件
   - 解压到任意位置（如桌面、Downloads 等）
2. **一键安装**
   - 双击 `installer.app`
   - 按照图形界面提示完成安装
   - 安装完成后可删除下载的文件夹

### 方法二：命令行安装

```bash
# 1. 下载项目
git clone https://github.com/the3asic/hsp-minimeters-safezone.git
cd hsp-minimeters-safezone

# 2. 运行安装脚本
./setup.sh
```

### 方法三：静默安装（脚本自动化）

```bash
./setup.sh install -s
```

## 🎮 使用方法

1. **启动 Hammerspoon**
   - 第一次需要授予辅助功能权限
   - 系统偏好设置 > 安全性与隐私 > 辅助功能
2. **配置 MiniMeters**
   - 使用项目提供的 `MiniMeters-config.json` 配置
   - 或手动设置位置为底部 32px 区域
3. **验证效果**
   - 最大化任意窗口，观察自动避开底部区域
   - 拖拽窗口到底部，观察自动高度调整

## 🔧 管理工具

### 检查更新

```bash
# 检查是否有新版本
./setup.sh check

# 或在已安装的情况下双击 installer.app
```

### 更新到最新版

```bash
# 交互式更新
./setup.sh

# 静默更新
./setup.sh install -s
```

### 卸载

```bash
# 交互式卸载
./setup.sh uninstall

# 或通过图形界面选择卸载选项
```

## ⚙️ MiniMeters 配置

### 推荐配置

使用项目提供的 `MiniMeters-config.json`：

```json
{
  "window": {
    "always_on_top": true,
    "collapse_main_menu": false,
    "custom_position": {
      "anchor": "BottomLeft",
      "h": 32,
      "w": "stick",
      "x": "stick",
      "y": -32
    },
    "default_position": "custom"
  }
}
```

### 手动激活

⚠️ **重要**：配置后需要手动激活：
1. 启动 MiniMeters
2. 点击菜单栏中的 "Default Position" 按钮
3. MiniMeters 会移动到底部保护区域

## 🔍 故障排除

### 常见问题

**❌ 安装失败**
- 确保已安装 Hammerspoon：`brew install --cask hammerspoon`
- 检查文件权限：`chmod +x setup.sh`

**❌ 脚本不工作**
- 检查 Hammerspoon 辅助功能权限
- 查看 Hammerspoon 控制台错误信息

**❌ 窗口调整异常**
- 在控制台运行 `wbm.showStatus()` 检查状态
- 确认 MiniMeters 位置正确

**❌ MiniMeters 位置错误**
- 检查配置文件语法是否正确
- 确认 `y: -32` 是负值
- 重启 MiniMeters 应用

### 获取帮助

```bash
# 查看所有可用选项
./setup.sh --help

# 检查详细状态
# 在 Hammerspoon 控制台运行：
wbm.showStatus()
wbm.checkAllWindows()
```

## 🔄 版本管理

脚本会自动：
- 📋 记录安装版本
- 🌐 检查 GitHub 最新版本  
- 🔄 提示可用更新
- 📦 保持配置文件同步

版本信息存储在 `~/.hammerspoon/.wbm_version`

## 🏗️ 技术架构

- **定时检查**：每 2 秒轻量级扫描
- **智能排除**：自动识别系统窗口和工具面板
- **边界保护**：动态调整窗口高度，避免重叠
- **多显示器友好**：自动适配屏幕配置变化
- **性能优化**：最小资源占用，稳定运行

## 📜 许可协议

本项目采用开源许可。欢迎提交 Issues 和 Pull Requests！

---

💡 **提示**：安装完成后可以安全删除下载的文件夹，配置已部署到系统目录。 