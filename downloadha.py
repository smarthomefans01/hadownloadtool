#!/usr/bin/env python3

import os
import sys
import subprocess
import shutil
import json


def check_and_install(*tools):
    for tool in tools:
        if not shutil.which(tool):
            print(f"{tool} 没有被安装，正在自动安装...")
            if os.geteuid() != 0:
                print(f"请使用 sudo 权限重新运行此脚本以安装 {tool}.")
                sys.exit(1)
            else:
                print("正在更新软件包列表...")
                subprocess.run(["apt-get", "update"])
                print(f"正在安装 {tool}...")
                subprocess.run(["apt-get", "install", "-y", tool])
                print(f"{tool} 安装成功！")
        else:
            print(f"{tool} 已经被安装，无需再次安装。")

check_and_install("curl", "jq")
print("所有工具都已经准备好，脚本执行完毕。")

repo_url = input("请输入第三方集成在GitHub的仓库地址: ")
full_name = repo_url.split("github.com/")[-1].replace(".git", "")
print(f"REPO_PATH={full_name}")

print("正在获取集成数据...")
data = subprocess.run(["curl", "-s", "https://data-v2.hacs.xyz/integration/data.json"], capture_output=True)
data = json.loads(data.stdout.decode('utf-8'))

matched_integration = None
for integration_id, integration_data in data.items():
    if integration_data["full_name"] == full_name:
        matched_integration = integration_data
        break

if not matched_integration:  
    print("未找到对应的集成信息")  
    sys.exit(1)  

DOMAIN = matched_integration["domain"]
ARCHIVE_TAG = matched_integration["last_version"]
REPO_PATH = full_name

print(f"已获取到集成信息，域名为 {DOMAIN}，最后的版本为 {ARCHIVE_TAG}，仓库路径为 {REPO_PATH}")
print("脚本执行完毕。")

# 定义变量
tmpPath = "/tmp/hatmp"
HUB_DOMAIN = "ghproxy.com/github.com"
REPO_NAME = os.path.basename(REPO_PATH)

# 设置默认值
DOMAIN = DOMAIN or "hacs"
REPO_PATH = REPO_PATH or "hacs-china/integration"
ARCHIVE_TAG = ARCHIVE_TAG or (sys.argv[1] if len(sys.argv) > 1 else "master")
HUB_DOMAIN = HUB_DOMAIN or "github.com"

# 如果DOMAIN为"hacs"且ARCHIVE_TAG为"main"、"china"或"master"，则更新ARCHIVE_TAG为"latest"
if DOMAIN == "hacs" and ARCHIVE_TAG in ["main", "china", "master"]:
    ARCHIVE_TAG = "latest"

# 根据上述值构造压缩包的下载地址
ARCHIVE_URL = f"https://{HUB_DOMAIN}/{REPO_PATH}/archive/{ARCHIVE_TAG}.zip"

if ARCHIVE_TAG == "latest":
    ARCHIVE_URL = f"https://{HUB_DOMAIN}/{REPO_PATH}/releases/{ARCHIVE_TAG}/download/{DOMAIN}.zip"

# 输出信息、警告和错误的函数
def info(message):
    print(f"信息: {message}")

def warn(message):
    print(f"警告: {message}")

def error(message, exit_on_error=True):
    print(f"错误: {message}")
    if exit_on_error:
        sys.exit(1)

# 检查必要的工具
def check_requirement(tool):
    if not shutil.which(tool):
        error(f"'{tool}' 没有安装")

check_requirement("wget")
check_requirement("unzip")
check_requirement("find")
check_requirement("jq")

# 输出压缩包地址和其他信息
info(f"压缩包地址: {ARCHIVE_URL}")
info("尝试找到正确的目录...")

ccPath = "/usr/share/hassio/homeassistant/custom_components"

if not os.path.exists(ccPath):
    info("创建 custom_components 目录...")
    os.makedirs(ccPath)

if not os.path.exists(tmpPath):
    os.makedirs(tmpPath)

info("切换到临时目录...")
os.chdir(tmpPath)

info("下载...")
subprocess.run(["wget", "-t", "2", "-O", f"{tmpPath}/{DOMAIN}.zip", ARCHIVE_URL], check=True)

info("解压...")
subprocess.run(["unzip", "-o", f"{tmpPath}/{DOMAIN}.zip", "-d", tmpPath], check=True, stdout=subprocess.PIPE)

# 查找包含 manifest.json 的目录
domain_dirs = [root for root, dirs, files in os.walk(tmpPath) if "manifest.json" in files and os.path.basename(root) == DOMAIN]

if not domain_dirs:
    error("找不到包含 'manifest.json' 的 '{DOMAIN}' 命名目录")

final_dir = domain_dirs[0]

info(f"找到正确的目录: {final_dir}")

if os.path.exists(f"{ccPath}/{DOMAIN}"):
    info("存在旧版本，尝试删除...")
    shutil.rmtree(f"{ccPath}/{DOMAIN}")

info("复制新版本...")
shutil.copytree(final_dir, f"{ccPath}/{DOMAIN}")

# 检查更新是否成功
manifest_path = f"{ccPath}/{DOMAIN}/manifest.json"
if not os.path.exists(manifest_path):
    warn("manifest.json文件不存在，请检查是否下载和解压正确。跳过检查更新是否成功。")
else:
    with open(manifest_path, 'r') as f:
        manifest_data = json.load(f)
        version = manifest_data.get("version", "")
        if version == ARCHIVE_TAG.replace("v", ""):
            info(f"更新成功。当前版本为：{version}")
        else:
            warn(f"更新失败。版本不匹配。期望版本为：{ARCHIVE_TAG.replace('v', '')}，实际版本为：{version}")

# 清理临时文件
info("删除临时文件...")
shutil.rmtree(tmpPath)
