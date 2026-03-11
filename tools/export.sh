#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_PATH:-/Users/yangguang/Downloads/Godot.app/Contents/MacOS/Godot}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo -e "${CYAN}像素深渊 导出工具${NC}"
    echo ""
    echo "用法: $0 [选项] [平台...]"
    echo ""
    echo "平台:"
    echo "  mac        导出 macOS 版本"
    echo "  windows    导出 Windows 版本"
    echo "  all        导出所有平台 (默认)"
    echo ""
    echo "选项:"
    echo "  -d, --debug     导出调试版本 (默认: release)"
    echo "  -c, --clean     导出前清理 build 目录"
    echo "  -v, --version   设置版本号 (例: -v 0.2.0)"
    echo "  -h, --help      显示帮助"
    echo ""
    echo "环境变量:"
    echo "  GODOT_PATH      自定义 Godot 可执行文件路径"
    echo ""
    echo "示例:"
    echo "  $0                   # 导出所有平台 release 版本"
    echo "  $0 mac               # 只导出 macOS"
    echo "  $0 -d mac windows    # 导出调试版本"
    echo "  $0 -c -v 0.2.0 all   # 清理后以 0.2.0 版本导出"
}

if ! [ -x "$(command -v "$GODOT" 2>/dev/null)" ] && ! [ -f "$GODOT" ]; then
    echo -e "${RED}错误: 找不到 Godot，请设置 GODOT_PATH 环境变量${NC}"
    echo "  例: GODOT_PATH=/path/to/Godot $0"
    exit 1
fi

MODE="release"
CLEAN=false
VERSION=""
PLATFORMS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)   MODE="debug"; shift ;;
        -c|--clean)   CLEAN=true; shift ;;
        -v|--version) VERSION="$2"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        mac|windows|all) PLATFORMS+=("$1"); shift ;;
        *) echo -e "${RED}未知参数: $1${NC}"; usage; exit 1 ;;
    esac
done

[[ ${#PLATFORMS[@]} -eq 0 ]] && PLATFORMS=("all")

EXPORT_MAC=false
EXPORT_WIN=false
for p in "${PLATFORMS[@]}"; do
    case $p in
        mac)     EXPORT_MAC=true ;;
        windows) EXPORT_WIN=true ;;
        all)     EXPORT_MAC=true; EXPORT_WIN=true ;;
    esac
done

if $CLEAN; then
    echo -e "${YELLOW}清理 build 目录...${NC}"
    rm -rf "$PROJECT_DIR/build"
fi

mkdir -p "$PROJECT_DIR/build/mac" "$PROJECT_DIR/build/windows"

export_flag="--export-release"
[[ "$MODE" == "debug" ]] && export_flag="--export-debug"

SUCCESS=()
FAILED=()

if $EXPORT_MAC; then
    echo -e "${CYAN}━━━ 导出 macOS ($MODE) ━━━${NC}"
    if "$GODOT" --headless --path "$PROJECT_DIR" $export_flag "macOS" 2>&1; then
        size=$(du -sh "$PROJECT_DIR/build/mac/像素深渊.zip" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓ macOS 导出成功 → build/mac/像素深渊.zip ($size)${NC}"
        SUCCESS+=("macOS")
    else
        echo -e "${RED}✗ macOS 导出失败${NC}"
        FAILED+=("macOS")
    fi
    echo ""
fi

if $EXPORT_WIN; then
    echo -e "${CYAN}━━━ 导出 Windows ($MODE) ━━━${NC}"
    if "$GODOT" --headless --path "$PROJECT_DIR" $export_flag "Windows" 2>&1; then
        size=$(du -sh "$PROJECT_DIR/build/windows/像素深渊.exe" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓ Windows 导出成功 → build/windows/像素深渊.exe ($size)${NC}"
        SUCCESS+=("Windows")
    else
        echo -e "${RED}✗ Windows 导出失败${NC}"
        FAILED+=("Windows")
    fi
    echo ""
fi

echo -e "${CYAN}━━━ 导出完成 ━━━${NC}"
[[ ${#SUCCESS[@]} -gt 0 ]] && echo -e "${GREEN}成功: ${SUCCESS[*]}${NC}"
[[ ${#FAILED[@]} -gt 0 ]]  && echo -e "${RED}失败: ${FAILED[*]}${NC}"

if [[ ${#SUCCESS[@]} -gt 0 ]]; then
    echo ""
    echo "产出文件:"
    $EXPORT_MAC && [ -f "$PROJECT_DIR/build/mac/像素深渊.zip" ] && \
        echo "  macOS:   build/mac/像素深渊.zip ($(du -sh "$PROJECT_DIR/build/mac/像素深渊.zip" | cut -f1))"
    $EXPORT_WIN && [ -f "$PROJECT_DIR/build/windows/像素深渊.exe" ] && \
        echo "  Windows: build/windows/像素深渊.exe ($(du -sh "$PROJECT_DIR/build/windows/像素深渊.exe" | cut -f1))"
fi

[[ ${#FAILED[@]} -gt 0 ]] && exit 1
exit 0
