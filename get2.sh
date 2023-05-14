#!/bin/bash
# 这是一个用于安装 hacs 的 bash 脚本
# wget -q -O - https://raw.githubusercontent.com/hasscc/get/main/get | DOMAIN=hacs REPO_PATH=hacs-china/integration bash -
# 使用 wget 命令从网址下载脚本并执行，可以指定 DOMAIN 和 REPO_PATH 参数

set -e
# 设置 -e 选项，如果脚本中出现错误，立即退出

DOMAIN=${DOMAIN:-hacs}
# 如果没有指定 DOMAIN 参数，就默认为 hacs

REPO_PATH=${REPO_PATH:-hacs-china/integration}
# 如果没有指定 REPO_PATH 参数，就默认为 hacs-china/integration

REPO_NAME=$(basename "$REPO_PATH")
# 从 REPO_PATH 中提取仓库名，赋值给 REPO_NAME 变量

ARCHIVE_TAG=${ARCHIVE_TAG:-$1}
# 如果没有指定 ARCHIVE_TAG 参数，就使用第一个位置参数

ARCHIVE_TAG=${ARCHIVE_TAG:-master}
# 如果还没有指定 ARCHIVE_TAG 参数，就默认为 master

HUB_DOMAIN=${HUB_DOMAIN:-github.com}
# 如果没有指定 HUB_DOMAIN 参数，就默认为 github.com

ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/archive/$ARCHIVE_TAG.zip"
# 拼接压缩包的下载地址，赋值给 ARCHIVE_URL 变量

if [ "$ARCHIVE_TAG" = "latest" ]; then
  ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/releases/$ARCHIVE_TAG/download/$DOMAIN.zip"
fi
# 如果 ARCHIVE_TAG 等于 latest，就使用 releases 目录下的压缩包地址

if [ "$DOMAIN" = "hacs" ]; then
  if [ "$ARCHIVE_TAG" = "main" ] || [ "$ARCHIVE_TAG" = "china" ] || [ "$ARCHIVE_TAG" = "master" ]; then
    ARCHIVE_TAG="latest"
  fi
  # 如果 DOMAIN 等于 hacs，并且 ARCHIVE_TAG 等于 main 或 china 或 master，就将 ARCHIVE_TAG 改为 latest
  ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/releases/$ARCHIVE_TAG/download/$DOMAIN.zip"
  # 使用 releases 目录下的压缩包地址
fi

function info () {
  echo "INFO: $1"
}
# 定义一个 info 函数，用于输出信息文字

function warn () {
  echo "WARN: $1"
}
# 定义一个 warn 函数，用于输出警告文字

function error () {
  echo "ERROR: $1"
  if [ "$2" != "false" ]; then
    if [ -d "$tmpPath" ]; then # 检查临时文件夹是否存在
      info "Removing temp files..."
      rm -rf "$tmpPath/$DOMAIN.zip"
      rm -rf "$tmpPath/$domainDir"
      rm -rf "$tmpPath"
    fi
    exit 1 # 删除临时文件夹后退出脚本
  fi
}
# 定义一个 error 函数，用于输出错误文字，并且根据第二个参数决定是否退出脚本

function checkRequirement () {
  if ! command -v "$1" >/dev/null; then
    error "'$1' is not installed"
  fi
}
# 定义一个 checkRequirement 函数，用于检查是否安装了某个命令，如果没有安装就报错并退出

checkRequirement "wget"
checkRequirement "unzip"
checkRequirement "zipinfo"
# 调用 checkRequirement 函数检查是否安装了 wget、unzip 和 zipinfo 命令

info "Archive URL: $ARCHIVE_URL"
info "Trying to find the correct directory..."
# 输出压缩包地址和寻找配置目录的信息

ccPath="/usr/share/hassio/homeassistant/custom_components"
# 将 ccPath 改为指定的地址

if [ ! -d "$ccPath" ]; then
    info "Creating custom_components directory..."
    mkdir "$ccPath"
    # 如果 ccPath 目录不存在，就创建它，并输出信息
fi

tmpPath="/tmp/hatmp"
# 定义一个 tmpPath 变量，存放临时文件夹的路径

if [ ! -d "$tmpPath" ]; then
    info "Creating temp directory..."
    mkdir "$tmpPath"
    # 如果 tmpPath 目录不存在，就创建它，并输出信息
fi

info "Changing to the temp directory..."
cd "$tmpPath" || error "Could not change path to $tmpPath"
# 切换到 tmpPath 目录下，如果失败就报错并退出，并输出信息
info "Downloading..."
wget -t 2 -O "$tmpPath/$DOMAIN.zip" "$ARCHIVE_URL"
# 使用 wget 命令下载压缩包到 tmpPath 目录下，并重命名为 $DOMAIN.zip，并输出信息


info "Unpacking..."
# 输出解压缩的信息

zipfile=$(find . -maxdepth 1 -type f -name "*$DOMAIN*.zip" | head -n 1) # 使用 find 命令在当前目录下寻找命名包含 $DOMAIN 字眼的压缩文件，并取第一个结果赋值给 zipfile 变量

if [ ! -f "$zipfile" ]; then # 如果 zipfile 变量为空或者不是一个文件，就报错并退出，并输出中文错误信息
    error "Could not find any zip file containing '$DOMAIN'"
    false
    error "找不到任何包含 '$DOMAIN' 的压缩文件"
fi

unzip -o "$zipfile" -d "$tmpPath" >/dev/null 2>&1 # 使用 unzip 命令解压 zipfile 文件到 tmpPath 目录，并忽略输出信息

domainDir=$(find . -maxdepth 1 -type d -name "*$DOMAIN*" | head -n 1)
# 使用 find 命令在当前目录下寻找命名包含 $DOMAIN 字眼的文件夹，并取第一个结果赋值给 domainDir 变量

if [ ! -d "$domainDir" ]; then
    error "Could not find any directory containing '$DOMAIN'"
    false
    error "找不到任何包含 '$DOMAIN' 的文件夹"
    # 如果 domainDir 变量为空或者不是一个目录，就报错并退出，并输出中文错误信息
fi

subDir=$(find "$domainDir" -mindepth 1 -maxdepth 1 -type d -name "*$DOMAIN*" | head -n 1)
# 使用 find 命令在 domainDir 目录下寻找一级子目录中命名包含 $DOMAIN 字眼的文件夹，并取第一个结果赋值给 subDir 变量

if [ ! -z "$subDir" ]; then
    domainDir=$(basename "$subDir") # 如果 subDir 变量不为空，就说明 domainDir 下一级有包含 $DOMAIN 字眼的文件夹，就将 subDir 的基本名赋值给 domainDir 变量
fi

if [ "$(basename "$domainDir")" != "$DOMAIN" ]; then
    error "Could not find any directory named '$DOMAIN'"
    false
    error "找不到任何命名为 '$DOMAIN' 的文件夹"
    # 如果 domainDir 的基本名不等于 $DOMAIN ，就报错并退出，并输出中文错误信息
fi


if [ -d "$ccPath/$domainDir" ]; then
    warn "custom_components/$domainDir directory already exist, cleaning up..."
    rm -Rf "${ccPath:?}/$domainDir/"
   # 如果 ccPath 目录下已经有 domainDir 目录，就输出警告信息，并删除该目录及其下面的所有文件和文件夹（使用 ${ccPath:?} 防止 ccPath 为空）
fi

cp -rf "$tmpPath/$domainDir" "$ccPath"
# 将 tmpPath/domainDir 目录复制到 ccPath 目录下


info "Removing temp files..."
rm -rf "$tmpPath/$DOMAIN.zip"
rm -rf "$tmpPath/$domainDir"
rm -rf "$tmpPath"
# 删除临时文件夹及其下面的所有文件和文件夹

info "Done!"
# 输出完成的信息
