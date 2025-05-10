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

# 默认不启用 --no-log-file 参数
NO_LOG_FILE=false

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
    echo "  --clean        Clean build artifacts"
    echo "  --help         Show this help message"
    echo "  --no-log-file  Do not log output to file, output to terminal instead"
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
        --no-log-file)
            NO_LOG_FILE=true
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


# 构建函数
build_for_abi() {
    local ABI="$1"
    local LOG_FILE="$LOG_DIR/build_${ABI}.log"

    echo "Building for $ABI..."
    if [ "$NO_LOG_FILE" = false ]; then
        echo "Logging to $LOG_FILE"
    fi

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
    
    export CFLAGS="-D__ANDROID_API__=$API_LEVEL --sysroot=$SYSROOT -Wl,-z,max-page-size=16384"

    # 配置
    if [ "$NO_LOG_FILE" = true ]; then
        ./configure \
            --prefix="$OUTPUT_DIR/$ABI" \
            --host="$HOST" \
            CC="$CC" \
            AR="$AR" \
            CFLAGS="$CFLAGS"
    else
        ./configure \
            --prefix="$OUTPUT_DIR/$ABI" \
            --host="$HOST" \
            CC="$CC" \
            AR="$AR" \
            CFLAGS="$CFLAGS" > "$LOG_FILE" 2>&1
    fi

    # 编译和安装
    if [ "$NO_LOG_FILE" = true ]; then
        make
        make install
    else
        make >> "$LOG_FILE" 2>&1
        make install >> "$LOG_FILE" 2>&1
    fi
    
    # 清理中间文件
    if [ "$NO_LOG_FILE" = true ]; then
        make clean
    else
        make clean >> "$LOG_FILE" 2>&1
    fi
    
    echo "Build for $ABI completed. Output in $OUTPUT_DIR/$ABI"
    echo
}

# 主构建过程
for ABI in "${ABIS[@]}"; do
    build_for_abi "$ABI"
done

echo
echo "All builds completed successfully!"
echo "Output binaries are in: $OUTPUT_DIR"
