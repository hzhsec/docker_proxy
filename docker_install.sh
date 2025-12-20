#!/bin/bash

# Kali Linux Docker 全自动安装脚本 (动态识别版本版)
# 逻辑：自动检测 Debian 基础代号 -> 安装 -> 执行镜像源配置 -> 启动

set -e

# --- 路径配置 ---
PARENT_DIR="./"
CUSTOM_SCRIPT="$PARENT_DIR/docker_yuan.sh"
DOCKER_GPG_PATH="/etc/apt/keyrings/docker.gpg"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== 1. 自动化版本检测 ===${NC}"

# 获取系统架构
ARCH=$(dpkg --print-architecture)

# 核心逻辑：检测底层的 Debian 代号
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "kali" ]; then
        # 从 debian_version 读取版本号，并映射到代号
        # Kali 通常返回 "trixie/sid"，取第一个词
        DEBIAN_BASE=$(cut -d/ -f1 /etc/debian_version)
        
        case $DEBIAN_BASE in
            12*) DEBIAN_CODENAME="bookworm" ;;
            13*) DEBIAN_CODENAME="trixie" ;;
            *)   
                # 如果是字母（如 trixie），直接使用；如果是数字且未匹配，默认设为 trixie
                if [[ $DEBIAN_BASE =~ ^[a-zA-Z]+$ ]]; then
                    DEBIAN_CODENAME=$DEBIAN_BASE
                else
                    DEBIAN_CODENAME="trixie" 
                fi
                ;;
        esac
        echo -e "${GREEN}检测到 Kali Linux，匹配 Debian 仓库代号为: ${DEBIAN_CODENAME}${NC}"
    else
        DEBIAN_CODENAME=$VERSION_CODENAME
        echo -e "${GREEN}检测到标准发行版: ${ID} (${DEBIAN_CODENAME})${NC}"
    fi
else
    echo -e "${RED}错误：无法识别操作系统类型${NC}"
    exit 1
fi

echo -e "\n${YELLOW}=== 2. 环境清理与依赖安装 ===${NC}"
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
sudo apt update
sudo apt install -y ca-certificates curl gnupg dirmngr

echo -e "\n${YELLOW}=== 3. 配置 Docker 官方密钥与动态仓库 ===${NC}"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg | \
sudo gpg --dearmor --yes -o "$DOCKER_GPG_PATH"
sudo chmod a+r "$DOCKER_GPG_PATH"

# 使用检测到的 DEBIAN_CODENAME
echo "deb [arch=${ARCH} signed-by=${DOCKER_GPG_PATH}] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian ${DEBIAN_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo -e "\n${YELLOW}=== 4. 安装 Docker 组件 ===${NC}"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 预创建配置目录
sudo mkdir -p /etc/docker

echo -e "\n${YELLOW}=== 5. 执行镜像源配置脚本 ===${NC}"
if [ -f "$CUSTOM_SCRIPT" ]; then
    echo -e "正在执行: $CUSTOM_SCRIPT"
    bash "$CUSTOM_SCRIPT" || { echo -e "${RED}镜像源配置失败${NC}"; exit 1; }
else
    echo -e "${YELLOW}未检测到 $CUSTOM_SCRIPT，跳过换源${NC}"
fi

echo -e "\n${YELLOW}=== 6. 服务初始化与权限配置 ===${NC}"
sudo systemctl daemon-reload
sudo systemctl enable --now docker

# 将当前用户加入 docker 组
if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
    sudo usermod -aG docker $USER
    echo -e "${GREEN}用户 $USER 已加入 docker 组${NC}"
fi

echo -e "\n${GREEN}=== 安装成功！ ===${NC}"
echo -e "系统架构: ${ARCH}"
echo -e "软件源代号: ${DEBIAN_CODENAME}"
docker --version

echo -e "\n${YELLOW}提示：请运行 'newgrp docker' 或重启终端使组权限生效。${NC}"
