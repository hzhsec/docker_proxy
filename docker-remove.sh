
# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== 开始深度清理 Docker 环境 ===${NC}"

# 1. 停止所有 Docker 相关服务
echo "正在停止 Docker 服务..."
sudo systemctl stop docker.service 2>/dev/null
sudo systemctl stop docker.socket 2>/dev/null
sudo systemctl stop containerd 2>/dev/null

# 2. 卸载软件包
DOCKER_PACKAGES=$(dpkg -l | grep -iE 'docker|containerd|runc' | awk '{print $2}')

if [ -z "$DOCKER_PACKAGES" ]; then
    echo -e "${GREEN}未检测到安装的 Docker 软件包。${NC}"
else
    echo "发现相关包：$DOCKER_PACKAGES"
    sudo apt purge -y $DOCKER_PACKAGES
    sudo apt autoremove -y
    sudo apt autoclean
fi

# 3. 处理挂载点（防止 rm -rf 失败）
echo "正在检查并清理挂载点..."
mount | grep "/var/lib/docker" | awk '{print $3}' | xargs -r sudo umount

# 4. 删除目录和残留文件
echo "清理文件系统残留..."
FILES=(
    "/var/lib/docker"
    "/var/lib/containerd"
    "/etc/docker"
    "/etc/apparmor.d/docker"
    "/var/run/docker.sock"
    "/usr/local/bin/docker-compose"
    "/etc/systemd/system/docker.service.d"
)

for file in "${FILES[@]}"; do
    if [ -e "$file" ]; then
        sudo rm -rf "$file"
        echo "已删除: $file"
    fi
done

# 清理当前用户和 $SUDO_USER 的家目录配置
rm -rf ~/.docker
if [ -n "$SUDO_USER" ]; then
    rm -rf "/home/$SUDO_USER/.docker"
fi

# 5. 清理网络接口
if ip link show docker0 >/dev/null 2>&1; then
    echo "清理 docker0 网桥..."
    sudo ip link delete docker0
fi

# 6. 删除用户组
if getent group docker > /dev/null; then
    sudo groupdel docker
fi

echo -e "\n${GREEN}=== 卸载完成！建议执行 'sudo reboot' 重启系统 ===${NC}"
