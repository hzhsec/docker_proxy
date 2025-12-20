#!/bin/bash

# 颜色输出（可选，美观）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== 开始彻底卸载 Docker ===${NC}"

# 第1步：提取所有包含 docker 的已安装包名（只取第二列）
echo "正在扫描已安装的 Docker 相关包..."
DOCKER_PACKAGES=$(dpkg -l | grep -i docker | awk '{print $2}')

if [ -z "$DOCKER_PACKAGES" ]; then
    echo -e "${GREEN}未检测到任何 Docker 相关包，已干净！${NC}"
else
    echo "检测到的 Docker 包："
    echo "$DOCKER_PACKAGES" | sed 's/^/  - /'
    
    # 第2步：卸载这些包
    echo -e "\n${YELLOW}正在执行卸载：sudo apt purge -y $DOCKER_PACKAGES${NC}"
    sudo apt purge -y $DOCKER_PACKAGES
    
    # 第3步：清理依赖和缓存
    echo "清理无用依赖和缓存..."
    sudo apt autoremove -y
    sudo apt autoclean
fi

# 第4步：再次检查是否还有残留包
echo -e "\n${YELLOW}卸载后再次检查残留包...${NC}"
RESIDUAL_PACKAGES=$(dpkg -l | grep -i docker | awk '{print $2}')
if [ -n "$RESIDUAL_PACKAGES" ]; then
    echo -e "${RED}警告：仍有以下包未卸载干净：${NC}"
    echo "$RESIDUAL_PACKAGES" | sed 's/^/  - /'
else
    echo -e "${GREEN}软件包已全部卸载干净！${NC}"
fi

# 第5步：删除常见残留文件和目录
echo -e "\n${YELLOW}正在删除 Docker 残留文件和目录...${NC}"
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -rf /var/run/docker.sock
sudo rm -rf /usr/bin/docker*
sudo rm -rf /usr/bin/containerd*
sudo rm -rf /usr/bin/ctr*
sudo rm -rf /usr/bin/runc*
sudo rm -rf ~/.docker  # 当前用户家目录下的配置

# 删除 docker 用户组（如果存在）
if getent group docker > /dev/null; then
    echo "删除 docker 用户组..."
    sudo groupdel docker
fi

# 第6步：最终验证
echo -e "\n${YELLOW}最终验证 Docker 是否彻底移除...${NC}"
if command -v docker > /dev/null 2>&1; then
    echo -e "${RED}错误：docker 命令仍然存在！（路径：$(which docker)）${NC}"
else
    echo -e "${GREEN}成功：docker 命令已不存在，卸载彻底完成！${NC}"
fi

echo -e "\n${GREEN}=== Docker 卸载脚本执行完毕 ===${NC}"
echo "建议重启系统以确保所有残留进程完全清除：sudo reboot"
