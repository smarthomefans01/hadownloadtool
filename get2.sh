#!/bin/bash

set -e

# 把tmpPath变量的定义位置提前了
tmpPath="/tmp/hatmp"

# 退出时删除临时文件
trap 'rm -rf "$tmpPath"' EXIT

# 设置默认值
[ -z "$DOMAIN" ] && DOMAIN="hacs"
[ -z "$REPO_PATH" ] && REPO_PATH="hacs-china/integration"

REPO_NAME=$(basename "$REPO_PATH")

[ -z "$ARCHIVE_TAG" ] && ARCHIVE_TAG="$1"
[ -z "$ARCHIVE_TAG" ] && ARCHIVE_TAG="master"

[ -z "$HUB_DOMAIN" ] && HUB_DOMAIN="github.com"

ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/archive/$ARCHIVE_TAG.zip"

if [ "$ARCHIVE_TAG" = "latest" ]; then
  ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/releases/$ARCHIVE_TAG/download/$DOMAIN.zip"
fi

if [ "$DOMAIN" = "hacs" ]; then
  if [ "$ARCHIVE_TAG" = "main" ] || [ "$ARCHIVE_TAG" = "china" ] || [ "$ARCHIVE_TAG" = "master" ]; then
    ARCHIVE_TAG="latest"
  fi
  ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/releases/$ARCHIVE_TAG/download/$DOMAIN.zip"
fi

function info () {
  echo "信息: $1"
}

function warn () {
  echo "警告: $1"
}

function error () {
  echo "错误: $1"
  # 如果第二个参数为"true"，脚本会继续运行，否则会退出。
  if [ "$2" != "true" ]; then
    exit 1
  fi
}

function checkRequirement () {
  if [ -z "$(command -v "$1")" ]; then
    error "'$1' 没有安装"
  fi
}

checkRequirement "wget"
checkRequirement "unzip"
checkRequirement "find"
checkRequirement "jq"

info "压缩包地址: $ARCHIVE_URL"
info "尝试找到正确的目录..."

ccPath="/usr/share/hassio/homeassistant/custom_components"

if [ ! -d "$ccPath" ]; then
    info "创建 custom_components 目录..."
    mkdir "$ccPath"
fi

[ -d "$tmpPath" ] || mkdir "$tmpPath"

info "切换到临时目录..."
cd "$tmpPath" || error "无法切换到 $tmpPath 目录"

info "下载..."
wget -t 2 -O "$tmpPath/$DOMAIN.zip" "$ARCHIVE_URL"

info "解压..."
unzip -o "$tmpPath/$DOMAIN.zip" -d "$tmpPath" >/dev/null 2>&1

domainDirs=$(find "$tmpPath" -type d -name "$DOMAIN")

# 找到包含manifest.json文件的目录，并优先使用有子目录的情况
for domainDir in $domainDirs; do
    if [ -f "$domainDir/manifest.json" ]; then
        subDir=$(find "$domainDir" -mindepth 1 -maxdepth 1 -type d -name "$DOMAIN" | head -n 1)
        if [ -z "$subDir" ]; then
            finalDir="$domainDir"
            break # 跳出循环
        fi
    fi
done

if [ -z "$finalDir" ]; then
    error "找不到包含 'manifest.json' 的 '$DOMAIN' 命名目录，且没有 '$DOMAIN' 命名子目录"
fi

info "找到正确的目录: $finalDir"

# 检查是否存在旧版本，并删除
if [ -d "$ccPath/$DOMAIN" ]; then 
    info "存在旧版本，尝试删除..."
    rm -rf "$ccPath/$DOMAIN" || error "删除旧版本失败，请手动删除或重试。"
else 
    info "不存在旧版本，直接复制新版本..."
fi

info "复制新版本..."
[ -d "$ccPath/$DOMAIN" ] || mkdir "$ccPath/$DOMAIN"
cp -R "$finalDir/"* "$ccPath/$DOMAIN/"

# 检查更新是否成功
if [ ! -f "$ccPath/$DOMAIN/manifest.json"]; then # 检查manifest.json文件是否存在
    warn "manifest.json文件不存在，请检查是否下载和解压正确。跳过检查更新是否成功。"
elif ! jq '.version' <"$ccPath/$DOMAIN/manifest.json"; then # 检查manifest.json文件是否包含version字段
    warn "manifest.json文件不包含version字段，请检查是否下载和解压正确。跳过检查更新是否成功。"
else # 如果存在并且包含，则进行检查更新是否成功的步骤。
    info "检查版本..."
    version=$(jq '.version' <"$ccPath/$DOMAIN/manifest.json")
    if [ "${version//\"}" = "${ARCHIVE_TAG//v}" ]; then
        info "更新成功。当前版本为：${version//\"}"
    else
        warn "更新失败。版本不匹配。期望版本为：${ARCHIVE_TAG//v}，实际版本为：${version//\"}"
    fi
fi

