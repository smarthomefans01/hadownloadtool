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
  echo "INFO: $1"
}

function warn () {
  echo "WARN: $1"
}

function error () {
  echo "ERROR: $1"
  if [ "$2" != "false" ]; then
    if [ -d "$tmpPath" ]; then
      info "Removing temp files..."
      [ -f "$tmpPath/$DOMAIN.zip" ] && rm -rf "$tmpPath/$DOMAIN.zip"
      [ -d "$tmpDir" ] && rm -rf "$tmpDir"
      rm -rf "$tmpPath"
    fi
    exit 1
  fi
}

function checkRequirement () {
  if [ -z "$(command -v "$1")" ]; then
    error "'$1' is not installed"
  fi
}

checkRequirement "wget"
checkRequirement "unzip"
checkRequirement "find"

info "Archive URL: $ARCHIVE_URL"
info "Trying to find the correct directory..."

ccPath="/usr/share/hassio/homeassistant/custom_components"

if [ ! -d "$ccPath" ]; then
    info "Creating custom_components directory..."
    mkdir "$ccPath"
fi

tmpPath="/tmp/hatmp"

[ -d "$tmpPath" ] || mkdir "$tmpPath"

info "Changing to the temp directory..."
cd "$tmpPath" || error "Could not change path to $tmpPath"

info "Downloading..."
wget -t 2 -O "$tmpPath/$DOMAIN.zip" "$ARCHIVE_URL"

info "Unpacking..."
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
    error "Could not find any directory named '$DOMAIN' containing 'manifest.json' and no '$DOMAIN' named sub-directory"
    false
    error "找不到包含 'manifest.json' 的 '$DOMAIN' 命名目录，且没有 '$DOMAIN' 命名子目录"
fi

info "Found correct directory: $finalDir"

info "Removing old version..."
rm -rf "$ccPath/$DOMAIN"

info "Copying new version..."
[ -d "$ccPath/$DOMAIN" ] || mkdir "$ccPath/$DOMAIN"
cp -R "$finalDir/"* "$ccPath/$DOMAIN/"

info "Removing temp files..."
[ -f "$tmpPath/$DOMAIN.zip" ] && rm -rf "$tmpPath/$DOMAIN.zip"
tmpDir=$(find "$tmpPath/"*"$REPO_NAME-$ARCHIVE_TAG"* | head -n 1)
[ -d "$tmpDir" ] && rm -rf "$tmpDir"
rm -rf "$tmpPath"

info "Done."
