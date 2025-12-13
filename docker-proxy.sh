#!/bin/bash

# --- 配置部分 ---
CONFIG_FILE="proxies.txt"
DOCKER_CONF_DIR="/etc/systemd/system/docker.service.d"
DOCKER_CONF_FILE="$DOCKER_CONF_DIR/http-proxy.conf"

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
PLAIN='\033[0m'

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}请使用 sudo 运行此脚本${PLAIN}"
  exit 1
fi

# 读取配置文件
load_proxies() {
    PROXY_URLS=()
    PROXY_NAMES=()
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}未找到 $CONFIG_FILE，将使用默认空列表。${PLAIN}"
        echo "请在同目录下创建 $CONFIG_FILE，格式: protocol://ip:port # 备注"
        return
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过空行和纯注释行
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        # 提取 URL (第一个空格或 # 之前的内容)
        url=$(echo "$line" | awk -F '[#[:space:]]' '{print $1}')
        # 提取备注 (第一个 # 之后的内容，如果没有则使用 URL)
        name=$(echo "$line" | awk -F '#' '{if(NF>1) $1=""; print $0}' | sed 's/^[[:space:]]*//')
        
        if [ -z "$name" ]; then name="$url"; fi
        
        if [ -n "$url" ]; then
            PROXY_URLS+=("$url")
            PROXY_NAMES+=("$name")
        fi
    done < "$CONFIG_FILE"
}

# 测试代理连通性
test_proxy() {
    local url=$1
    echo -n "   测试连通性... "
    # 使用 curl 通过代理访问 google.com (或是国内能访问的稳定外网 checkip)
    # --connect-timeout 2: 连接超时 2 秒
    # -I: 只请求头
    if curl -s -I --connect-timeout 2 -x "$url" https://www.google.com >/dev/null; then
        echo -e "${GREEN}通畅 ✅${PLAIN}"
        return 0
    else
        echo -e "${RED}失败 ❌ (建议不要使用)${PLAIN}"
        return 1
    fi
}

show_status() {
    if [ -f "$DOCKER_CONF_FILE" ]; then
        current_proxy=$(grep 'HTTP_PROXY' "$DOCKER_CONF_FILE" | cut -d'"' -f2)
        echo -e "\n🔍 Docker 当前状态：${GREEN}已启用代理${PLAIN}"
        echo -e "   地址：$current_proxy"
    else
        echo -e "\n🔍 Docker 当前状态：${RED}未启用代理${PLAIN}"
    fi
}

apply_proxy() {
    local proxy_url="$1"
    
    # 再次确认连通性
    echo -e "\n👉 准备应用: $proxy_url"
    test_proxy "$proxy_url"
    
    mkdir -p "$DOCKER_CONF_DIR"
    cat <<EOF > "$DOCKER_CONF_FILE"
[Service]
Environment="HTTP_PROXY=$proxy_url"
Environment="HTTPS_PROXY=$proxy_url"
Environment="NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
EOF

    echo -e "🔄 正在重载配置并重启 Docker..."
    systemctl daemon-reload
    systemctl restart docker
    echo -e "${GREEN}✅ 代理已设置成功！${PLAIN}"
}

disable_proxy() {
    if [ ! -f "$DOCKER_CONF_FILE" ]; then
        echo -e "${YELLOW}当前未配置代理，无需关闭。${PLAIN}"
        return
    fi
    
    echo -e "\n👉 正在关闭 Docker 代理..."
    rm -f "$DOCKER_CONF_FILE"
    systemctl daemon-reload
    systemctl restart docker
    echo -e "${GREEN}❌ 代理已关闭，Docker 直连模式。${PLAIN}"
}

# --- 主逻辑 ---

load_proxies

# 支持命令行参数 (例如: ./script.sh off 或 ./script.sh 1)
if [ -n "$1" ]; then
    case "$1" in
        off|disable|stop)
            disable_proxy
            exit 0
            ;;
        [0-9]*)
            idx=$(($1 - 1))
            if [dir "$idx" -ge 0 ] && [ "$idx" -lt "${#PROXY_URLS[@]}" ]; then
                 apply_proxy "${PROXY_URLS[$idx]}"
                 exit 0
            else
                echo "无效的索引"
                exit 1
            fi
            ;;
    esac
fi

# 交互菜单
while true; do
    clear
    echo -e "========== 🐳 Docker 代理管理 =========="
    show_status
    echo -e "========================================"
    
    for i in "${!PROXY_URLS[@]}"; do
        echo -e "${CYAN}$((i+1)))${PLAIN} 启用: ${PROXY_NAMES[i]}"
        # 可选：这里如果不嫌慢，可以把下一行注释打开，菜单里直接显示连通性
        # test_proxy "${PROXY_URLS[i]}" 
    done
    
    echo -e "${CYAN}0)${PLAIN} 关闭代理"
    echo -e "${CYAN}q)${PLAIN} 退出"
    
    echo -e "----------------------------------------"
    read -p "请输入选项: " choice
    
    case "$choice" in
        0)
            disable_proxy
            read -p "按回车键继续..."
            ;;
        q|Q)
            echo "👋 Bye!"
            exit 0
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]]; then
                idx=$((choice - 1))
                if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#PROXY_URLS[@]}" ]; then
                    apply_proxy "${PROXY_URLS[$idx]}"
                    read -p "按回车键继续..."
                else
                    echo -e "${RED}无效选项${PLAIN}"
                    sleep 1
                fi
            else
                echo -e "${RED}请输入数字${PLAIN}"
                sleep 1
            fi
            ;;
    esac
done