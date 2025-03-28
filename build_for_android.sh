#!/bin/bash

set -e

# 默认参数
DEFAULT_API_LEVEL=28
DEFAULT_NDK_HOME="$HOME/Android/Sdk/ndk-bundle"
DEFAULT_OUTPUT_DIR="$(dirname $0)/android_build/outputs"
DEFAULT_LOG_DIR="$(dirname $0)/android_build/logs"

# 从环境变量或参数获取配置
NDK_HOME="${NDK_HOME:-$DEFAULT_NDK_HOME}"
API_LEVEL="${API_LEVEL:-$DEFAULT_API_LEVEL}"
OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"
LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"

# 支持的ABI列表
ABIS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")

# 工具链路径
TOOLCHAIN="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

# 清理函数
clean() {
    echo "Cleaning build directories..."
    rm -rf "$OUTPUT_DIR" "$LOG_DIR" arm64_build
    make clean > /dev/null 2>&1 || true
    echo "Clean complete."
}

# 帮助信息
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --clean       Clean build artifacts"
    echo "  --help        Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  NDK_HOME      Path to Android NDK (default: $DEFAULT_NDK_HOME)"
    echo "  API_LEVEL     Android API level (default: $DEFAULT_API_LEVEL)"
    echo "  OUTPUT_DIR    Output directory (default: $DEFAULT_OUTPUT_DIR)"
    echo "  LOG_DIR       Log directory (default: $DEFAULT_LOG_DIR)"
}

# 处理参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            clean
            exit 0
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# 检查NDK
if [ ! -d "$NDK_HOME" ]; then
    echo "Error: NDK not found at $NDK_HOME"
    echo "Please set NDK_HOME environment variable or install the NDK"
    exit 1
fi

# 创建目录
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

TPARAM_FILE="lib/termcap/tparam.c"

# 添加补丁
add_patches() {
    if ! grep -q "#include <unistd.h>" "$TPARAM_FILE"; then
        if [ -f "$TPARAM_FILE" ]; then
            cp "$TPARAM_FILE" "$TPARAM_FILE.bak"
        fi
        sed -i '1i#include <unistd.h>' "$TPARAM_FILE"
        echo "Added unistd.h to $TPARAM_FILE"
    fi
}

# 恢复原始文件
restore_patches() {
    if [ -f "$TPARAM_FILE.bak" ]; then
        mv "$TPARAM_FILE.bak" "$TPARAM_FILE"
        echo "Restored original $TPARAM_FILE"
    fi
}

# 构建函数
build_for_abi() {
    local ABI="$1"
    local LOG_FILE="$LOG_DIR/build_${ABI}.log"
    
    echo "Building for $ABI..."
    echo "Logging to $LOG_FILE"

    # 设置ABI特定参数
    case "$ABI" in
        armeabi-v7a)
            HOST="armv7a-linux-androideabi"
            TARGET="arm-linux-androideabi"
            CLANG_PREFIX="armv7a-linux-androideabi"
            ;;
        arm64-v8a)
            HOST="aarch64-linux-android"
            TARGET="aarch64-linux-android"
            CLANG_PREFIX="aarch64-linux-android"
            ;;
        x86)
            HOST="i686-linux-android"
            TARGET="i686-linux-android"
            CLANG_PREFIX="i686-linux-android"
            ;;
        x86_64)
            HOST="x86_64-linux-android"
            TARGET="x86_64-linux-android"
            CLANG_PREFIX="x86_64-linux-android"
            ;;
        *)
            echo "Unsupported ABI: $ABI"
            return 1
            ;;
    esac

    # 设置编译器和标志
    local CC="$TOOLCHAIN/bin/${CLANG_PREFIX}${API_LEVEL}-clang"
    local AR="$TOOLCHAIN/bin/llvm-ar"
    local SYSROOT="$TOOLCHAIN/sysroot"
    
    export CFLAGS="-D__ANDROID_API__=$API_LEVEL --sysroot=$SYSROOT"

    # 配置
    ./configure \
        --prefix="$OUTPUT_DIR/$ABI" \
        --host="$HOST" \
        CC="$CC" \
        AR="$AR" \
        CFLAGS="$CFLAGS"> "$LOG_FILE" 2>&1

    # 编译和安装
    make >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    
    # 清理中间文件
    make clean >> "$LOG_FILE" 2>&1
    
    echo "Build for $ABI completed. Output in $OUTPUT_DIR/$ABI"
    echo
}

# 主构建过程
add_patches

for ABI in "${ABIS[@]}"; do
    build_for_abi "$ABI"
done

restore_patches

echo
echo "All builds completed successfully!"
echo "Output binaries are in: $OUTPUT_DIR"