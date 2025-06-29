#!/bin/bash

# Hammerspoon 窗口边界监控器 - 智能安装/更新/卸载脚本
# 支持交互式和静默模式

set -e

HAMMERSPOON_DIR="$HOME/.hammerspoon"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$HAMMERSPOON_DIR/.wbm_version"
CURRENT_VERSION="1.0.1"
GITHUB_REPO="the3asic/hsp-minimeters-safezone"  # 修改为你的实际仓库名

# 解析命令行参数
ACTION=""
SILENT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        install|update)
            ACTION="install"
            ;;
        uninstall|remove)
            ACTION="uninstall"
            ;;
        check)
            ACTION="check"
            ;;
        -s|--silent)
            SILENT=true
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  install, update    安装或更新窗口边界监控器"
            echo "  uninstall, remove  卸载窗口边界监控器"
            echo "  check              检查当前版本和 GitHub 最新版本"
            echo "  -s, --silent       静默模式（不询问确认）"
            echo "  -h, --help         显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                 交互式运行"
            echo "  $0 install -s      静默安装/更新"
            echo "  $0 uninstall       卸载"
            echo "  $0 check           检查版本"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 $0 --help 查看帮助"
            exit 1
            ;;
    esac
    shift
done

# 显示标题
if [ "$SILENT" = false ]; then
    echo "🔨 Hammerspoon 窗口边界监控器管理工具"
    echo "===================================="
    echo ""
fi

# 检查 Hammerspoon 是否已安装
check_hammerspoon() {
    if ! command -v hs &> /dev/null && [ ! -d "/Applications/Hammerspoon.app" ]; then
        echo "❌ 未检测到 Hammerspoon，请先安装"
        echo ""
        echo "📥 安装方法："
        echo "   方法一（推荐）：brew install --cask hammerspoon"
        echo "   方法二：前往 https://www.hammerspoon.org/ 下载安装包"
        echo ""
        exit 1
    fi
    [ "$SILENT" = false ] && echo "✅ 检测到 Hammerspoon"
}

# 获取 GitHub 最新版本
get_github_version() {
    local latest_version=""
    
    # 尝试从 GitHub API 获取最新 release 版本
    if command -v curl &> /dev/null; then
        latest_version=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "")
    elif command -v wget &> /dev/null; then
        latest_version=$(wget -qO- "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "")
    fi
    
    # 如果没有获取到 release，尝试检查仓库是否存在
    if [ -z "$latest_version" ] && command -v curl &> /dev/null; then
        local repo_check=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$GITHUB_REPO" 2>/dev/null || echo "000")
        if [ "$repo_check" = "404" ]; then
            echo "REPO_NOT_FOUND"
        else
            echo "NO_RELEASES"
        fi
    else
        echo "$latest_version"
    fi
}

# 版本检查函数
check_version() {
    echo "🔍 检查版本信息..."
    echo ""
    
    # 当前已安装版本
    if [ -f "$VERSION_FILE" ]; then
        local installed_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "未知")
        echo "📦 已安装版本: $installed_version"
    else
        echo "❌ 未安装窗口边界监控器"
        echo ""
        return
    fi
    
    # 本地文件版本
    echo "📁 本地文件版本: $CURRENT_VERSION"
    
    # GitHub 版本检查
    echo "🌐 检查 GitHub 最新版本..."
    local github_version=$(get_github_version)
    
    case "$github_version" in
        "REPO_NOT_FOUND")
            echo "⚠️  GitHub 仓库未找到或网络连接问题"
            ;;
        "NO_RELEASES")
            echo "⚠️  GitHub 仓库暂无 release 版本"
            ;;
        "")
            echo "⚠️  无法获取 GitHub 版本信息（网络问题或 API 限制）"
            ;;
        *)
            echo "🚀 GitHub 最新版本: $github_version"
            
            # 版本比较
            if [ "$installed_version" = "$github_version" ]; then
                echo "✅ 已安装最新版本"
            elif [ "$CURRENT_VERSION" = "$github_version" ]; then
                echo "✅ 本地文件为最新版本"
                if [ "$installed_version" != "$CURRENT_VERSION" ]; then
                    echo "💡 建议运行更新以应用最新版本到系统"
                fi
            else
                echo "🔄 发现新版本可用"
                if [ "$SILENT" = false ]; then
                    echo ""
                    read -p "是否立即更新到最新版本？(y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        ACTION="install"
                        return 1  # 信号继续执行安装
                    fi
                fi
            fi
            ;;
    esac
    echo ""
}

# 卸载函数
uninstall() {
    echo "🗑️  准备卸载窗口边界监控器..."
    
    if [ ! -f "$HAMMERSPOON_DIR/window_boundary_monitor.lua" ]; then
        echo "❌ 未找到已安装的窗口边界监控器"
        exit 1
    fi
    
    if [ "$SILENT" = false ]; then
        echo ""
        echo "将删除以下文件："
        echo "  - $HAMMERSPOON_DIR/window_boundary_monitor.lua"
        echo "  - $HAMMERSPOON_DIR/init.lua"
        echo "  - $VERSION_FILE"
        echo ""
        read -p "确认卸载？(y/N): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ 卸载已取消"
            exit 1
        fi
    fi
    
    # 删除文件
    rm -f "$HAMMERSPOON_DIR/window_boundary_monitor.lua"
    rm -f "$HAMMERSPOON_DIR/init.lua"
    rm -f "$VERSION_FILE"
    
    echo "✅ 卸载完成"
    
    # 如果 Hammerspoon 目录为空，提醒用户
    if [ -z "$(ls -A "$HAMMERSPOON_DIR" 2>/dev/null)" ]; then
        echo ""
        echo "💡 Hammerspoon 配置目录已空，你可以："
        echo "   - 保留 Hammerspoon 应用（不占用资源）"
        echo "   - 或卸载 Hammerspoon：brew uninstall --cask hammerspoon"
    fi
}

# 安装/更新函数
install_or_update() {
    # 判断是安装还是更新
    IS_UPDATE=false
    if [ -f "$HAMMERSPOON_DIR/window_boundary_monitor.lua" ]; then
        IS_UPDATE=true
        [ "$SILENT" = false ] && echo "🔄 检测到已安装的窗口边界监控器，将执行更新"
        
        # 读取已安装版本
        if [ -f "$VERSION_FILE" ]; then
            INSTALLED_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "未知")
            [ "$SILENT" = false ] && echo "   当前版本: $INSTALLED_VERSION → 新版本: $CURRENT_VERSION"
        fi
    else
        [ "$SILENT" = false ] && echo "🆕 将执行全新安装"
        
        # 检查是否有其他配置需要备份
        if [ -d "$HAMMERSPOON_DIR" ] && [ -f "$HAMMERSPOON_DIR/init.lua" ]; then
            if [ "$SILENT" = false ]; then
                echo ""
                echo "⚠️  检测到其他 Hammerspoon 配置"
                echo "📄 现有配置文件预览："
                echo "---"
                head -10 "$HAMMERSPOON_DIR/init.lua" 2>/dev/null || echo "无法读取现有配置"
                echo "---"
                echo ""
                read -p "🔄 是否备份现有配置并继续？(y/N): " -n 1 -r
                echo
                
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "❌ 安装已取消"
                    exit 1
                fi
            fi
            
            # 创建备份
            BACKUP_DIR="$HOME/.hammerspoon_backup_$(date +%Y%m%d_%H%M%S)"
            echo "📦 备份现有配置到: $BACKUP_DIR"
            cp -r "$HAMMERSPOON_DIR" "$BACKUP_DIR"
            [ "$SILENT" = false ] && echo "✅ 备份完成"
        fi
    fi
    
    # 创建目录
    [ ! -d "$HAMMERSPOON_DIR" ] && mkdir -p "$HAMMERSPOON_DIR"
    
    # 复制文件
    [ "$SILENT" = false ] && echo ""
    if [ "$IS_UPDATE" = true ]; then
        [ "$SILENT" = false ] && echo "📋 更新配置文件..."
    else
        [ "$SILENT" = false ] && echo "📋 安装配置文件..."
    fi
    
    cp -f "$SCRIPT_DIR/window_boundary_monitor.lua" "$HAMMERSPOON_DIR/"
    cp -f "$SCRIPT_DIR/init.lua" "$HAMMERSPOON_DIR/"
    echo "$CURRENT_VERSION" > "$VERSION_FILE"
    
    [ "$SILENT" = false ] && echo "✅ 文件操作完成"
    
    # 检查环境
    if [ "$SILENT" = false ]; then
        echo ""
        echo "🔍 环境检查..."
        if pgrep -x "MiniMeters" > /dev/null; then
            echo "✅ MiniMeters 正在运行"
        else
            echo "⚠️  MiniMeters 未运行"
        fi
    fi
    
    # 重新加载 Hammerspoon
    if pgrep -x "Hammerspoon" > /dev/null; then
        [ "$SILENT" = false ] && echo ""
        [ "$SILENT" = false ] && echo "🔄 重新加载 Hammerspoon 配置..."
        
        if command -v hs &> /dev/null; then
            hs -c "hs.reload()" 2>/dev/null && {
                [ "$SILENT" = false ] && echo "✅ 配置已重新加载"
            } || {
                [ "$SILENT" = false ] && echo "   请手动重新加载（菜单栏 → Reload Config）"
            }
        fi
    else
        [ "$SILENT" = false ] && echo ""
        [ "$SILENT" = false ] && echo "🚀 启动 Hammerspoon..."
        open -a "Hammerspoon"
        sleep 3
    fi
    
    # 完成提示
    if [ "$SILENT" = false ]; then
        echo ""
        if [ "$IS_UPDATE" = true ]; then
            echo "🎉 更新完成！"
        else
            echo "🎉 安装完成！"
        fi
    fi
}

# 主流程
check_hammerspoon

# 如果没有指定动作，显示菜单
if [ -z "$ACTION" ] && [ "$SILENT" = false ]; then
    # 检查是否已安装
    if [ -f "$HAMMERSPOON_DIR/window_boundary_monitor.lua" ]; then
        echo "📦 已安装窗口边界监控器"
        if [ -f "$VERSION_FILE" ]; then
            echo "   版本: $(cat "$VERSION_FILE")"
        fi
        echo ""
        echo "请选择操作："
        echo "1) 检查版本"
        echo "2) 更新到最新版本"
        echo "3) 卸载"
        echo "4) 退出"
        echo ""
        read -p "请输入选项 (1-4): " -n 1 -r
        echo
        
        case $REPLY in
            1) ACTION="check" ;;
            2) ACTION="install" ;;
            3) ACTION="uninstall" ;;
            *) echo "退出"; exit 0 ;;
        esac
    else
        echo "🆕 未安装窗口边界监控器"
        echo ""
        echo "请选择操作："
        echo "1) 安装"
        echo "2) 退出"
        echo ""
        read -p "请输入选项 (1-2): " -n 1 -r
        echo
        
        case $REPLY in
            1) ACTION="install" ;;
            *) echo "退出"; exit 0 ;;
        esac
    fi
fi

# 执行动作
case $ACTION in
    install)
        install_or_update
        ;;
    uninstall)
        uninstall
        ;;
    check)
        check_version
        if [ $? -eq 1 ]; then
            # 用户选择了立即更新
            install_or_update
        fi
        ;;
    *)
        echo "❌ 未指定有效操作"
        exit 1
        ;;
esac

# 清理提示
if [ "$SILENT" = false ] && [ "$ACTION" = "install" ]; then
    echo ""
    echo "💡 提示："
    echo "   - 查看状态: wbm.showStatus()"
    echo "   - 此脚本可重复运行用于更新"
    echo "   - 静默模式: $0 install -s"
    echo ""
    echo "📁 可以安全删除下载的文件夹"
fi