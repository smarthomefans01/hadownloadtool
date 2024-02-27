#!/bin/bash

# 第一步：拉取最新的homeassistant/home-assistant镜像
sudo docker pull homeassistant/home-assistant

# 第二步：停止名为hass的Home Assistant容器
sudo docker stop hass

# 第三步：强制删除标签为2023.8.4的homeassistant/home-assistant镜像
sudo docker rmi -f homeassistant/home-assistant:2023.8.4

# 第四步：获取homeassistant/home-assistant:latest的IMAGE_ID
IMAGE_ID=$(sudo docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep 'homeassistant/home-assistant:latest' | awk '{print $2}')

# 检查IMAGE_ID是否获取成功
if [ -z "$IMAGE_ID" ]; then
    echo "未找到homeassistant/home-assistant:latest的IMAGE_ID。"
    exit 1
fi

# 第五步：为IMAGE_ID添加新标签2023.8.4
sudo docker tag $IMAGE_ID homeassistant/home-assistant:2023.8.4

echo "更新完成。"

sudo docker start hass

echo "重启hass。"
