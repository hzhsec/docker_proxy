#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== 通用 Docker CE 安装脚本（支持 Ubuntu/Debian/Kali）===${NC}"
echo "使用清华镜像源安装 Docker CE，本脚本不手动配置镜像加速"
echo "将自动执行同级目录的 docker_yuan.sh 进行测速配置"
echo

# 检查是否为 root 或有 sudo 权限
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}正在使用 sudo 执行需要管理员权限的操作...${NC}"
fi

# 1. 更新系统并安装依赖
echo -e "${YELLOW}1. 更新软件源并安装必要依赖...${NC}"
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# 2. 获取系统 codename
CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
if [[ "$CODENAME" == "unknown" || -z "$CODENAME" ]]; then
    echo -e "${RED}无法检测系统版本，使用默认 'bookworm'（如有问题请手动修改）${NC}"
    CODENAME="bookworm"
fi
echo "检测到系统版本代号：${CODENAME}"

# 3. 创建 keyrings 目录并添加清华源的 Docker GPG 密钥
echo -e "${YELLOW}2. 添加 Docker GPG 密钥（清华镜像源）...${NC}"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. 添加清华 Docker 仓库
echo -e "${YELLOW}3. 添加清华 Docker CE 软件源...${NC}"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
  ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 更新源并安装 Docker
echo -e "${YELLOW}4. 更新软件源并安装 Docker CE...${NC}"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. 启动并启用 Docker 服务
echo -e "${YELLOW}5. 启动并设置 Docker 开机自启...${NC}"
sudo systemctl enable docker --now

# 7. 将当前用户加入 docker 组
CURRENT_USER=${SUDO_USER:-$(whoami)}
echo -e "${YELLOW}6. 将用户 ${CURRENT_USER} 加入 docker 组（重登录后生效）...${NC}"
sudo usermod -aG docker ${CURRENT_USER}

# 8. 执行同级目录下的 docker_yuan.sh 进行镜像源测速配置
echo -e "${YELLOW}7. 执行同级目录的 docker_yuan.sh 进行镜像加速测速配置...${NC}"
if [ -f "../docker_yuan.sh" ]; then
    if [ ! -x "../docker_yuan.sh" ]; then
        chmod +x ../docker_yuan.sh
    fi
    ../docker_yuan.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}docker_yuan.sh 执行成功，已完成镜像源配置${NC}"
        # 配置完成后重启 docker 使加速生效
        sudo systemctl restart docker
    else
        echo -e "${RED}docker_yuan.sh 执行失败，请手动检查${NC}"
    fi
else
    echo -e "${RED}未在同级目录找到 docker_yuan.sh，跳过镜像源测速配置${NC}"
fi

# 9. 测试安装
echo -e "${YELLOW}8. 测试 Docker 安装（运行 hello-world）...${NC}"
if docker run --rm hello-world; then
    echo -e "${GREEN}=== Docker 安装成功！===${NC}"
else
    echo -e "${RED}测试失败，请检查错误信息。${NC}"
    exit 1
fi

echo
echo -e "${GREEN}安装完成！请注销并重新登录（或重启系统），以使 docker 组权限生效。${NC}"
echo "之后你可以直接使用：docker run、docker ps 等命令，无需 sudo。"
echo
echo -e "${YELLOW}常用命令提醒：${NC}"
echo "  docker version          # 查看版本"
echo "  docker images           # 查看本地镜像"
echo "  docker ps               # 查看运行容器"
echo "  docker compose up       # 使用 Compose V2"