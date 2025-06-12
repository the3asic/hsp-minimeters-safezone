#!/bin/bash

# Hammerspoon 窗口边界监控器 - 安装脚本
# 专为与 MiniMeters 协同工作设计

set -e

HAMMERSPOON_DIR="$HOME/.hammerspoon"
BACKUP_DIR="$HOME/.hammerspoon_backup_$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔨 Hammerspoon 窗口边界监控器安装程序"
echo "=================================="

# 检查 Hammerspoon 是否已安装
if ! command -v hammerspoon &> /dev/null && [ ! -d "/Applications/Hammerspoon.app" ]; then
    echo "❌ 未检测到 Hammerspoon，请先安装"
    echo ""
    echo "📥 安装方法："
    echo "   方法一（推荐）：brew install --cask hammerspoon"
    echo "   方法二：前往 https://www.hammerspoon.org/ 下载安装包"
    echo ""
    echo "安装完成后重新运行此脚本"
    exit 1
fi

echo "✅ 检测到 Hammerspoon"

# 检查是否存在现有配置
if [ -d "$HAMMERSPOON_DIR" ]; then
    echo ""
    echo "⚠️  检测到现有 Hammerspoon 配置"
    
    if [ -f "$HAMMERSPOON_DIR/init.lua" ]; then
        echo "📄 现有配置文件预览："
        echo "---"
        head -10 "$HAMMERSPOON_DIR/init.lua" 2>/dev/null || echo "无法读取现有配置"
        echo "---"
    fi
    
    echo ""
    read -p "🔄 是否备份现有配置并继续安装？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 安装已取消"
        exit 1
    fi
    
    # 创建备份
    echo "📦 备份现有配置到: $BACKUP_DIR"
    cp -r "$HAMMERSPOON_DIR" "$BACKUP_DIR"
    echo "✅ 备份完成"
else
    echo "📁 创建 Hammerspoon 配置目录"
    mkdir -p "$HAMMERSPOON_DIR"
fi

# 复制配置文件
echo ""
echo "📋 安装配置文件..."

# 复制核心文件
cp "$SCRIPT_DIR/window_boundary_monitor.lua" "$HAMMERSPOON_DIR/"
cp "$SCRIPT_DIR/init.lua" "$HAMMERSPOON_DIR/"

echo "✅ 配置文件安装完成"

# 检查 MiniMeters 进程
echo ""
echo "🔍 检查 MiniMeters 状态..."
if pgrep -x "MiniMeters" > /dev/null; then
    echo "✅ 检测到 MiniMeters 正在运行"
else
    echo "⚠️  未检测到 MiniMeters 进程，请确保 MiniMeters 已启动"
fi

# 检查 Hammerspoon 是否正在运行
if pgrep -x "Hammerspoon" > /dev/null; then
    echo ""
    echo "🔄 检测到 Hammerspoon 正在运行，将重新加载配置..."
    osascript -e 'tell application "Hammerspoon" to reload config'
    sleep 2
else
    echo ""
    echo "🚀 启动 Hammerspoon..."
    open -a "Hammerspoon"
    sleep 3
fi

echo ""
echo "🎉 安装完成！"
echo ""
echo "📋 接下来的步骤："
echo "1. 确保 Hammerspoon 有辅助功能权限（系统偏好设置 > 安全性与隐私 > 辅助功能）"
echo "2. 配置 MiniMeters 窗口位置（参考 README.md 中的配置）"
echo "3. 测试窗口边界保护功能"
echo ""

if [ -d "$BACKUP_DIR" ]; then
    echo "📦 备份位置: $BACKUP_DIR"
    echo "   如需回滚，可使用: cp -r \"$BACKUP_DIR\"/* \"$HAMMERSPOON_DIR/\""
    echo ""
fi

echo "💡 提示："
echo "   - 要停止监控：退出 Hammerspoon 应用"
echo "   - 要修改边界高度：编辑 window_boundary_monitor.lua 文件"
echo "   - 查看状态：在 Hammerspoon 控制台运行 wbm.showStatus()"