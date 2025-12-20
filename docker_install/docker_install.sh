#!/bin/bash

# Kali Linux 安装 Docker 的脚本（使用清华镜像源，适用于当前 Kali Rolling / Debian Trixie）
# 新增：自动检测并执行上级目录的 docker_yuan.sh（镜像源配置脚本）
# 使用方法：sudo bash install_docker_kali.sh

set -e  # 遇到错误立即退出

# 检查上级目录是否有 docker_yuan.sh，如果有则先执行
PARENT_DIR="../"
CUSTOM_SCRIPT="$PARENT_DIR/docker_yuan.sh"

if [ -f "$CUSTOM_SCRIPT" ]; then
    echo "=== 检测到上级目录的镜像源配置脚本 $CUSTOM_SCRIPT，正在执行... ==="
    bash "$CUSTOM_SCRIPT" || {
        echo "执行 $CUSTOM_SCRIPT 失败，脚本终止。"
        exit 1
    }
    echo "=== 镜像源配置脚本执行完成 ==="
else
    echo "=== 未在上层目录找到 docker_yuan.sh，跳过自定义镜像源配置 ==="
fi

echo "=== 1. 更新系统并安装必要依赖 ==="
sudo apt update
sudo apt install -y ca-certificates curl gnupg dirmngr

echo "=== 2. 创建 keyrings 目录并添加 Docker 官方 GPG 密钥 ==="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "=== 3. 添加清华 Docker CE 源（trixie 对应当前 Kali）==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian trixie stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== 4. 更新源并安装 Docker 相关组件 ==="
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== 5. 启动并启用 Docker 服务（开机自启）==="
sudo systemctl enable --now docker

echo "=== 6. （可选）安装旧版独立 Docker Compose V1 ==="
sudo apt install -y docker-compose || echo "旧版 docker-compose 安装失败（可能已移除），建议使用 docker compose 插件"

echo "=== 7. 将当前用户加入 docker 组（避免每次使用 sudo）==="
sudo usermod -aG docker $USER
echo "请重新登录或重启系统使组变更生效！"

echo "=== 8. 测试 Docker 安装 ==="
echo "Docker 版本信息："
docker version

echo "本地镜像列表："
docker images

echo "运行中的容器："
docker ps

echo "正在测试拉取并运行 hello-world 镜像..."
# 如果已经配置了镜像加速器，这里用非 sudo 试试；若还没生效则 fallback 到 sudo
docker run --rm hello-world || sudo docker run --rm hello-world

echo "=================================="
echo "Docker 安装完成！"
echo "如果出现权限问题，请重新登录终端或重启系统后，再直接运行 docker 命令（无需 sudo）。"
echo "自定义镜像源配置（如有）已在上一步自动应用。"
