#!/bin/bash

set -e

# 检查并安装必要的工具
check_and_install() {
    for tool in "$@"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "$tool 没有被安装，正在自动安装..."
            if [[ $EUID -ne 0 ]]; then
                echo "请使用 sudo 权限重新运行此脚本以安装 $tool."
                exit 1
            else
                sudo apt-get update
                sudo apt-get install -y "$tool"
            fi
        fi
    done
}

# 检查并安装 curl 和 jq
check_and_install curl jq

echo "国内常见的插件下载："
echo "1. 插件名称：xiaomi miot auto；简介：处理米家wifi设备和所有米家设备云端对接。仓库地址：https://github.com/al-one/hass-xiaomi-miot"
echo "2. 插件名称：XiaomiGateway3；简介：处理米家蓝牙设备和部分zigbee设备对接。仓库地址：https://github.com/AlexxIT/XiaomiGateway3"
echo "3. 插件名称：AqaraGateway；简介：处理绿米网关设备对接；仓库地址：https://github.com/niceboygithub/AqaraGateway"
echo "4. 插件名称：SonoffLAN；简介：处理易微联设备对接；仓库地址：https://github.com/AlexxIT/SonoffLAN"
echo "5. 插件名称：Deebot-4-Home-Assistant；简介：处理科沃斯扫地机器人对接。仓库地址：https://github.com/DeebotUniverse/Deebot-4-Home-Assistant"
echo "6. 插件名称：localtuya；简介：涂鸦Wi-Fi设备本地对接；仓库地址：https://github.com/rospogrigio/localtuya"
echo "7. 插件名称：dreame-vacuum；简介：追觅扫地机或者吸尘器对接；仓库地址：https://github.com/Tasshack/dreame-vacuum"
echo "8. 插件名称：dahua；简介：大华摄像头和门铃对接。仓库地址：https://github.com/rroller/dahua"
echo "9. 插件名称：ha-tplink-deco；简介：tplink-deco设备对接。仓库地址：https://github.com/amosyuen/ha-tplink-deco"
echo "10. 插件名称：midea_ac_lan；简介：美的设备对接；仓库地址：https://github.com/georgezhao2010/midea_ac_lan"

echo "请输入您选择的插件序号，或者输入 0 来输入自定义的GitHub仓库地址："
read choice

case $choice in
    1)
        repo_url="https://github.com/al-one/hass-xiaomi-miot"
        ;;
    2)
        repo_url="https://github.com/AlexxIT/XiaomiGateway3"
        ;;
    3)
        repo_url="https://github.com/niceboygithub/AqaraGateway"
        ;;
    4)
        repo_url="https://github.com/AlexxIT/SonoffLAN"
        ;;
    5)
        repo_url="https://github.com/DeebotUniverse/Deebot-4-Home-Assistant"
        ;;
    6)
        repo_url="https://github.com/rospogrigio/localtuya"
        ;;
    7)
        repo_url="https://github.com/Tasshack/dreame-vacuum"
        ;;
    8)
        repo_url="https://github.com/rroller/dahua"
        ;;
    9)
        repo_url="https://github.com/amosyuen/ha-tplink-deco"
        ;;
    10)
        repo_url="https://github.com/georgezhao2010/midea_ac_lan"
        ;;
    0)
        read -p "请输入自定义的GitHub仓库地址: " repo_url
        ;;
    *)
        echo "无效的输入。"
        exit 1
        ;;
esac

echo "选择的GitHub仓库地址是：$repo_url"

# 从URL中提取GitHub仓库的full_name
full_name="${repo_url#*github.com/}"
full_name="${full_name%.git}"

# 输出仓库信息
echo "REPO_PATH=$full_name"



# 从URL中提取GitHub仓库的full_name
full_name="${repo_url#*github.com/}"
full_name="${full_name%.git}"

# 输出仓库信息
echo "REPO_PATH=$full_name"

# 使用curl获取JSON数据，并使用jq查找对应的full_name
data=$(curl -s "https://cdn.jsdelivr.net/gh/smarthomefans01/hadownloadtool@main/data.json" | jq -r --arg FULL_NAME "$full_name" '.[] | select(.full_name == $FULL_NAME)')

# 如果没有找到对应的数据，输出错误信息并退出
if [ -z "$data" ]; then
    echo "未找到对应的集成信息"
    exit 1
fi

# 使用jq从JSON数据中提取domain和last_version
DOMAIN=$(echo "$data" | jq -r '.domain')
ARCHIVE_TAG=$(echo "$data" | jq -r '.last_version')
REPO_PATH=$full_name

# 把tmpPath变量的定义位置提前了
tmpPath="/tmp/hatmp"
trap 'rm -rf "$tmpPath"' EXIT

HUB_DOMAIN="hub.gitmirror.com/https://github.com"

REPO_NAME=$(basename "$REPO_PATH")

[ -z "$DOMAIN" ] && DOMAIN="hacs"
[ -z "$REPO_PATH" ] && REPO_PATH="hacs-china/integration"


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
  # 如果第二个参数为"false"，脚本会继续运行，即使出现了错误。这可能会导致脚本在出现错误后继续运行，而不是立即停止。
  # 修改为：如果第二个参数为"true"，脚本会继续运行，否则会退出。
  if [ "$2" != "true" ]; then
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

[ -d "$tmpPath" ] || mkdir "$tmpPath"

info "切换到临时目录..."
cd "$tmpPath" || error "无法切换到 $tmpPath 目录"

info "下载..."
wget -t 2 -O "$tmpPath/$DOMAIN.zip" "$ARCHIVE_URL"

info "解压..."
unzip -o "$tmpPath/$DOMAIN.zip" -d "$tmpPath" >/dev/null 2>&1

domainDirs=$(find "$tmpPath" -type d -name "$DOMAIN")

# 脚本将所有找到的名为"$DOMAIN"的目录都存储在domainDirs变量中，然后遍历这些目录以找到包含"manifest.json"的目录。然而，如果有多个这样的目录，脚本只会使用最后一个。如果目标是使用第一个找到的目录，那么在找到一个符合条件的目录后，应该立即跳出循环。
# 修改为：在找到一个符合条件的目录后，使用break命令跳出循环。
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
    false
    error "找不到包含 'manifest.json' 的 '$DOMAIN' 命名目录，且没有 '$DOMAIN' 命名子目录"
fi

info "找到正确的目录: $finalDir"

info "删除旧版本..."
rm -rf "$ccPath/$DOMAIN"

# 脚本在尝试删除旧版本的"$DOMAIN"目录后，立即尝试创建一个新的"$DOMAIN"目录，然后将新版本复制到那里。这可能会导致在删除旧版本时出现错误，但脚本仍然会尝试复制新版本。
# 修改为：在尝试删除旧版本之前，先检查是否存在旧版本，并给出相应的提示。如果删除旧版本失败，就不要继续复制新版本。
if [ -d "$ccPath/$DOMAIN" ]; then # 检查是否存在旧版本
    info "存在旧版本，尝试删除..."
    rm -rf "$ccPath/$DOMAIN" || error "删除旧版本失败，请手动删除或重试。"
else # 如果不存在旧版本，就直接复制新版本
    info "不存在旧版本，直接复制新版本..."
fi

info "复制新版本..."
[ -d "$ccPath/$DOMAIN" ] || mkdir "$ccPath/$DOMAIN"
cp -R "$finalDir/"* "$ccPath/$DOMAIN/"

# 新增的功能，检查目标文件夹里面的manifest.json文件，提取它里面的version字段的信息，如果这个字段的信息等于"$ARCHIVE_TAG"，那么就表示更新成功了。
info "检查版本..."
version=$(jq '.version' <"$ccPath/$DOMAIN/manifest.json")
if [ "${version//\"}" = "${ARCHIVE_TAG//v}" ]; then
    info "更新成功。当前版本为：${version//\"}"
else
    warn "更新失败。版本不匹配。期望版本为：${ARCHIVE_TAG//v}，实际版本为：${version//\"}"
fi

# 在检查更新是否成功时，脚本使用了jq来解析manifest.json文件中的版本信息。然而，如果manifest.json文件不存在或不包含version字段，jq命令可能会失败，但脚本并未对此进行处理。
# 修改为：在使用jq命令之前，先检查manifest.json文件是否存在，并且是否包含version字段。如果不存在或不包含，则给出相应的警告，并跳过检查更新是否成功的步骤。
if [ ! -f "$ccPath/$DOMAIN/manifest.json" ]; then # 检查manifest.json文件是否存在
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


# 最后，脚本在完成后删除临时文件，但如果脚本在此之前的某个地方失败并退出，这些临时文件可能不会被删除。你
