#!/bin/bash

set -e
trap 'rm -rf "$tmpPath"' EXIT

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
  if [ "$2" != "false" ]; then
    if [ -d "$tmpPath" ]; then
      info "删除临时文件..."
      [ -f "$tmpPath/$DOMAIN.zip" ] && rm -rf "$tmpPath/$DOMAIN.zip"
      [ -d "$tmpDir" ] && rm -rf "$tmpDir"
      rm -rf "$tmpPath"
    fi
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

tmpPath="/tmp/hatmp"

[ -d "$tmpPath" ] || mkdir "$tmpPath"

info "切换到临时目录..."
cd "$tmpPath" || error "无法切换到 $tmpPath 目录"

info "下载..."
wget -t 2 -O "$tmpPath/$DOMAIN.zip" "$ARCHIVE_URL"

info "解压..."
unzip -o "$tmpPath/$DOMAIN.zip" -d "$tmpPath" >/dev/null 2>&1

domainDirs=$(find "$tmpPath" -type d -name "$DOMAIN")

for domainDir in $domainDirs; do
    if [ -f "$domainDir/manifest.json" ]; then
        subDir=$(find "$domainDir" -mindepth 1 -maxdepth 1 -type d -name "$DOMAIN" | head -n 1)
        if [ -z "$subDir" ]; then
            finalDir="$domainDir"
            break
        fi
    fi
done

if [ -z "$finalDir" ]; then
    error "找不到包含 'manifest.json' 的 '$DOMAIN' 命名目录，且没有 '$DOMAIN' 命名子目录"
    false
    error "找不到包含 'manifest.json' 的 '$DOMAIN' 命名目录，且没有 '$DOMAIN' 命名子目录"
fi

info "找到正确的目录: $finalDir"

info "删除旧版本..."
rm -rf "$ccPath/$DOMAIN"

info "复制新版本..."
[ -d "$ccPath/$DOMAIN" ] || mkdir "$ccPath/$DOMAIN"
cp -R "$finalDir/"* "$ccPath/$DOMAIN/"

# 新增的功能，检查目标文件夹里面的manifest.json文件，提取它里面的version字段的信息，如果这个字段的信息等于"$ARCHIVE_TAG"，那么就表示更新成功了。
info "检查版本..."
version=$(jq '.version' <"$ccPath/$DOMAIN/manifest.json")
if [ "${version//\"}" = "${ARCHIVE_TAG//v}" ]; then
    info "更新成功。"
else
    warn "更新失败。版本不匹配。"
fi

info "删除临时文件..."
[ -f "$tmpPath/$DOMAIN.zip" ] && rm -rf "$tmpPath/$DOMAIN.zip"
tmpDir=$(find "$tmpPath/"*"$REPO_NAME-$ARCHIVE_TAG"* | head -n 1)
[ -d "$tmpDir" ] && rm -rf "$tmpDir"
rm -rf "$tmpPath"

info "完成。"
