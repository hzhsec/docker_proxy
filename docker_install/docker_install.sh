#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== 修复版 Docker CE 安装脚本（专为 Kali/Ubuntu/Debian）===${NC}"
echo "自动处理 Kali rolling，使用官方 Docker 源 + trixie"

sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# 检测 codename，对于 Kali rolling 强制使用 trixie
CODENAME=$(lsb_release -cs 2>/dev/null)
if [[ "$CODENAME" == "kali-rolling" || "$CODENAME" == "n/a" ]]; then
    echo "检测到 Kali Linux rolling，强制使用 Debian trixie 仓库"
    CODENAME="trixie"
else
    echo "检测到系统代号：${CODENAME}"
fi

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable docker --now

CURRENT_USER=${SUDO_USER:-$(whoami)}
sudo usermod -aG docker ${CURRENT_USER}

# 执行你的 docker_yuan.sh（镜像加速测速）
if [ -f "../docker_yuan.sh" ]; then
    chmod +x ../docker_yuan.sh
    ../docker_yuan.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}镜像源配置成功，重启 Docker 生效${NC}"
        sudo systemctl restart docker
    fi
else
    echo -e "${RED}未找到 docker_yuan.sh，跳过镜像加速配置${NC}"
fi

# 测试
if docker run --rm hello-world; then
    echo -e "${GREEN}Docker 安装成功！${NC}"
else
    echo -e "${RED}测试失败${NC}"
fi

echo -e "${GREEN}安装完成！请重登录或重启，让 docker 组生效。${NC}"
