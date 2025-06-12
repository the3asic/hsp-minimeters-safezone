# Hammerspoon 窗口边界监控器

专为单显示器环境下与 MiniMeters 状态栏应用协同工作的 Hammerspoon 脚本。优雅地为 MiniMeters 让出屏幕底部 32 像素空间，确保即使窗口最大化或左右分屏时，也不会重叠状态栏。

## 项目文件

```
hammerspoon/
├── window_boundary_monitor.lua    # 核心监控模块
├── init.lua                       # Hammerspoon 初始化配置
├── install.sh                     # 自动安装脚本
├── MiniMeters-config.json         # MiniMeters 推荐配置参考
├── test.lua                       # 功能测试脚本
├── README.md                      # 项目说明（本文件）
└── CLAUDE.md                      # 技术架构文档
```

## 解决问题

- ✅ **窗口最大化时不遮挡 MiniMeters**
- ✅ **左右分屏时自动避开底部状态栏**
- ✅ **拖拽窗口到底部时自动调整高度**
- ✅ **极简设计，专注单一功能**

## 功能特点

- **极简设计**: 启动即工作，退出即停止，无复杂操作
- **定时监控**: 每2秒轻量级检查，稳定可靠
- **智能调整**: 自动缩减窗口高度，避免重叠 MiniMeters
- **最少排除**: 仅排除 Hammerspoon 和 MiniMeters 自身

## 安装

### 1. 下载项目（面向小白）

如果你是第一次使用 Git，请按以下步骤操作：

```bash
# 1. 打开终端（Terminal）
# 按 Command + 空格，搜索"终端"并打开

# 2. 选择一个下载位置（比如桌面）
cd ~/Desktop

# 3. 下载项目
git clone https://github.com/the3asic/hammerspoon-minimeters.git

# 4. 进入项目文件夹
cd hammerspoon-minimeters
```

💡 **不会用 Git？** 也可以：
1. 访问 [GitHub 项目页面](https://github.com/the3asic/hammerspoon-minimeters)
2. 点击绿色的 "Code" 按钮
3. 选择 "Download ZIP"
4. 解压缩到任意位置

### 2. 自动安装（推荐）

在项目文件夹中运行安装脚本：

```bash
./install.sh
```

安装脚本会：
- ✅ 检测现有配置并创建备份
- ✅ 安全部署新配置文件  
- ✅ 检查 Hammerspoon 和 MiniMeters 状态
- ✅ 自动重新加载配置

### 3. 手动安装（高级用户）

如果你更喜欢手动操作：

```bash
# 1. 安装 Hammerspoon (如果未安装)
# 方法一（推荐）：使用 Homebrew
brew install --cask hammerspoon

# 方法二：官网下载
# 前往 https://www.hammerspoon.org/ 下载 .dmg 安装包
# 拖拽到 Applications 文件夹完成安装

# 2. 部署配置文件
mkdir -p ~/.hammerspoon
cp window_boundary_monitor.lua ~/.hammerspoon/
cp init.lua ~/.hammerspoon/

# 3. 启动 Hammerspoon
open -a "Hammerspoon"
```

#### 手动配置 MiniMeters

编辑 MiniMeters 配置文件 `~/Library/Preferences/MiniMeters/settings.json`，将 `window` 部分设置为：

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

### 4. 权限设置

首次启动时需要授予 Hammerspoon 辅助功能权限：
**系统偏好设置 > 安全性与隐私 > 辅助功能** 中添加 Hammerspoon

## 使用

### 基本操作

- **启动监控**: 启动 Hammerspoon 应用即自动开始监控
- **停止监控**: 退出 Hammerspoon 应用即停止监控

## MiniMeters 配置

### 1. **重要：手动激活底部栏模式**

⚠️ **配置文件修改后，MiniMeters 不会自动定位到底部**，需要手动激活：

1. 启动 MiniMeters 后，**点击菜单栏中的 "Default Position" 按钮**
2. MiniMeters 会立即移动到屏幕底部 32px 区域
3. 此时 MiniMeters 位于窗口边界监控器保护的区域内

### 2. 多显示器环境注意事项

如果使用多显示器或经常切换显示器：
- **每次切换显示器后，需要重新点击 "Default Position"**
- **断开/连接外接显示器后，需要重新点击 "Default Position"**
- 建议将此操作作为切换显示器后的常规步骤

### 3. 验证效果

- MiniMeters 应显示在屏幕底部32像素区域
- 打开任意应用并最大化或拖拽到底部，观察窗口自动调整避开 MiniMeters

---

## 高级配置

### 边界高度调整

默认为 32 像素，修改方法：
1. 编辑 `window_boundary_monitor.lua` 文件
2. 修改 `BOUNDARY_HEIGHT = 32` 中的数值
3. 重新加载 Hammerspoon 配置

### 排除应用管理

默认仅排除：
- `Hammerspoon` - Hammerspoon 自身
- `MiniMeters` - MiniMeters 状态栏

所有其他应用窗口都会被监控和调整。

## 调试工具

如需调试，可在 Hammerspoon 控制台中使用：

```lua
-- 查看监控状态
wbm.showStatus()

-- 手动检查所有窗口
wbm.checkAllWindows()
```

## 故障排除

### 常见问题

**脚本不工作**
- 确保 Hammerspoon 有辅助功能权限
- 检查 Hammerspoon 控制台是否有错误信息

**某些窗口不被处理**  
- 仅 Hammerspoon 和 MiniMeters 被排除，其他应用都会被处理
- 在控制台运行 `wbm.showStatus()` 查看当前状态

**MiniMeters 位置不正确**
- 检查 MiniMeters 配置文件语法
- 确认 `y: -32` 是负值
- 重启 MiniMeters 应用

**恢复备份配置**
如果需要恢复之前的配置：
```bash
# 查看备份目录（安装脚本会显示）
ls -la ~/.hammerspoon_backup_*

# 恢复备份（替换时间戳）
cp -r ~/.hammerspoon_backup_YYYYMMDD_HHMMSS/* ~/.hammerspoon/
```

## 许可和贡献

这个脚本基于详细的 Hammerspoon API 分析和最佳实践开发。欢迎提出改进建议和bug报告。