#!/bin/bash

# 默认的基础路径
DEFAULT_BASE_PATH="/opt"

# 询问用户是否使用默认基础路径
echo "当前的默认路径是: $DEFAULT_BASE_PATH"
read -p "是否使用默认路径？(y/n): " USE_DEFAULT_PATH

echo "DEBUG: 用户选择了: $USE_DEFAULT_PATH"  # 调试输出

if [ "$USE_DEFAULT_PATH" == "y" ]; then
    # 如果用户选择使用默认路径
    BASE_PATH="$DEFAULT_BASE_PATH"
    echo "DEBUG: 使用默认路径 $BASE_PATH"  # 调试输出
else
    # 如果用户选择不使用默认路径，询问输入新路径
    read -p "请输入新的基础路径 (例如：/home/user): " BASE_PATH
    echo "DEBUG: 使用输入的路径 $BASE_PATH"  # 调试输出
fi

# 最后输出选择的路径
echo "最终的基础路径是: $BASE_PATH"

# 拼接最终的目标路径
DEST_DIR="${BASE_PATH}/1panel/resource/apps/local"

# 检查目标路径是否存在，如果不存在则提示用户并退出
if [ ! -d "$DEST_DIR" ]; then
    echo "指定的路径 $DEST_DIR 不存在，请检查路径并重新运行脚本。"
    exit 1
fi

# URL 和临时目录的定义
ZIP_URL="https://gh.llkk.cc/https://github.com/okxlin/appstore/archive/refs/heads/localApps.zip"
ZIP_FILE="${DEST_DIR}/localApps.zip"
TEMP_DIR="${DEST_DIR}/appstore-localApps"

# 检查并安装所需工具
check_and_install() {
    local package=$1
    if ! command -v $package &> /dev/null; then
        echo "$package 未安装，正在安装..."
        sudo apt-get update && sudo apt-get install -y $package
        if [ $? -ne 0 ]; then
            echo "$package 安装失败，请检查错误信息。"
            exit 1
        fi
    else
        echo "$package 已经安装。"
    fi
}

# 检查 unzip 和 wget 是否安装
check_and_install "unzip"
check_and_install "wget"

# 下载 zip 文件到指定目录
echo "Downloading the zip file..."
wget -P "$DEST_DIR" "$ZIP_URL"
if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络连接并重试。"
    exit 1
fi

# 解压 zip 文件到指定目录
echo "Unzipping the downloaded file..."
unzip -o -d "$DEST_DIR" "$ZIP_FILE"
if [ $? -ne 0 ]; then
    echo "解压失败，请检查 zip 文件是否完整或损坏。"
    exit 1
fi

# 检查解压后的文件
if [ ! -d "$TEMP_DIR/apps" ]; then
    echo "解压后的文件目录不存在，请检查解压是否正确。"
    exit 1
fi

# 拷贝解压后的文件到目标目录
echo "Copying extracted files..."
cp -rf "${TEMP_DIR}/apps/"* "$DEST_DIR"
if [ $? -ne 0 ]; then
    echo "拷贝文件失败，请检查文件权限或路径是否正确。"
    exit 1
fi

# 清理临时文件夹和 zip 文件
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
rm -f "$ZIP_FILE"
if [ $? -ne 0 ]; then
    echo "清理临时文件失败。"
    exit 1
fi

echo "Operation completed successfully."
