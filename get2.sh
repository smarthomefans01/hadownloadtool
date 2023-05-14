#!/bin/bash
# 这是一个用于安装 hacs 的 bash 脚本
# wget -q -O - https://raw.githubusercontent.com/hasscc/get/main/get | DOMAIN=hacs REPO_PATH=hacs-china/integration bash -
# 使用 wget 命令从网址下载脚本并执行，可以指定 DOMAIN 和 REPO_PATH 参数

set -e
# 设置 -e 选项，如果脚本中出现错误，立即退出

[ -z "$DOMAIN" ] && DOMAIN="hacs"
# 如果没有指定 DOMAIN 参数，就默认为 hacs

[ -z "$REPO_PATH" ] && REPO_PATH="hacs-china/integration"
# 如果没有指定 REPO_PATH 参数，就默认为 hacs-china/integration

REPO_NAME=$(basename "$REPO_PATH")
# 从 REPO_PATH 中提取仓库名，赋值给 REPO_NAME 变量

[ -z "$ARCHIVE_TAG" ] && ARCHIVE_TAG="$1"
# 如果没有指定 ARCHIVE_TAG 参数，就使用第一个位置参数

[ -z "$ARCHIVE_TAG" ] && ARCHIVE_TAG="master"
# 如果还没有指定 ARCHIVE_TAG 参数，就默认为 master

[ -z "$HUB_DOMAIN" ] && HUB_DOMAIN="github.com"
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


declare ccPath
# 声明 ccPath 变量

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
    exit 1
  fi
}
# 定义一个 error 函数，用于输出错误文字，并且根据第二个参数决定是否退出脚本

function checkRequirement () {
  if [ -z "$(command -v "$1")" ]; then
    error "'$1' is not installed"
  fi
}
# 定义一个 checkRequirement 函数，用于检查是否安装了某个命令，如果没有安装就报错并退出

checkRequirement "wget"
checkRequirement "unzip"
# 调用 checkRequirement 函数检查是否安装了 wget 和 unzip 命令

info "Archive URL: $ARCHIVE_URL"
info "Trying to find the correct directory..."
# 输出压缩包地址和寻找配置目录的信息


ccPath="/usr/share/hassio/homeassistant/custom_components"
# 直接指定 ccPath 的路径，而不用从 haPath 中拼接。
if [ ! -d "$ccPath" ]; then
  info "Creating custom_components directory..."
  mkdir "$ccPath"
  # 如果 ccPath 目录不存在，就创建它，并输出信息
fi
info "Changing to the custom_components directory..."
cd "$ccPath" || error "Could not change path to $ccPath"
# 切换到 ccPath 目录下，如果失败就报错并退出，并输出信息
info "Downloading..."
wget -t 2 -O "$ccPath/$DOMAIN$ARCHIVE_TAG.zip" "$ARCHIVE_URL"
# 使用 wget 命令下载压缩包到 ccPath 目录下，并重命名为 $DOMAIN$ARCHIVE_TAG.zip，并输出信息。把文件名改成 $DOMAIN$ARCHIVE_TAG.zip。

if [ -d "$ccPath/$DOMAIN" ]; then
  warn "custom_components/$DOMAIN directory already exist, cleaning up..."
  rm -R "$ccPath/$DOMAIN"
  # 如果 ccPath 目录下已经有 DOMAIN 目录，就输出警告信息，并删除该目录
fi

ver=${ARCHIVE_TAG/#v/}
# 去掉 ARCHIVE_TAG 中的 v 前缀，赋值给 ver 变量

if [ ! -d "$ccPath/$REPO_NAME-$ver" ]; then
  ver=$ARCHIVE_TAG
  # 如果 ccPath 目录下没有 REPO_NAME-ver 目录，就将 ver 变量改为 ARCHIVE_TAG
fi

info "Unpacking..."
# 输出解压缩的信息

str="/releases/"
# 定义一个 str 变量，存放 releases 字符串

if [ ${ARCHIVE_URL/${str}/} = $ARCHIVE_URL ]; then
  unzip -o "$ccPath/$DOMAIN$ARCHIVE_TAG.zip" -d "$ccPath" >/dev/null 2>&1
  # 如果 ARCHIVE_URL 中没有 str 字符串，就说明是从 archive 目录下载的压缩包，就直接解压到 ccPath 目录下，并忽略输出信息。把文件名改成 $DOMAIN$ARCHIVE_TAG.zip。
else
  dir="$ccPath/$REPO_NAME-$ver/custom_components/$DOMAIN"
  mkdir -p $dir
  unzip -o "$ccPath/$DOMAIN$ARCHIVE_TAG.zip" -d $dir >/dev/null 2>&1
  # 否则说明是从 releases 目录下载的压缩包，就先创建一个目录结构，然后解压到该目录下，并忽略输出信息。把文件名改成 $DOMAIN$ARCHIVE_TAG.zip。
fi

if [ ! -d "$ccPath/$REPO_NAME-$ver" ]; then
  error "Could not find $REPO_NAME-$ver directory"
  false
  error "找不到文件夹: $REPO_NAME-$ver"
  # 如果 ccPath 目录下没有 REPO_NAME-ver 目录，就报错并退出，并输出中文错误信息
fi

cp -rf "$ccPath/$REPO_NAME-$ver/custom_components/$DOMAIN" "$ccPath"
# 将 REPO_NAME-ver/custom_components/DOMAIN 目录复制到 ccPath 目录下

info "Removing temp files..."
rm -rf "$ccPath/$DOMAIN$ARCHIVE_TAG.zip"
rm -rf "$ccPath/$REPO_NAME-$ver"
# 删除临时文件，并输出信息

info "Installation complete."
info "安装成功！"
# 输出安装完成的信息和中文信息

echo
# 输出一个空行

info "Remember to restart Home Assistant before you configure it."
info "请重启 Home Assistant"
# 输出重启 Home Assistant 的提示和中文提示


