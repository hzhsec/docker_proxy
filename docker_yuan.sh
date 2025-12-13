#!/bin/bash

# --- 配置部分 ---
# 定义外部存放镜像 URL 的文件名
MIRROR_FILE="mirrors.txt"

# 检查文件是否存在
if [ ! -f "$MIRROR_FILE" ]; then
  echo "❌ 错误: 找不到文件 '$MIRROR_FILE'"
  echo "请在脚本同目录下创建该文件，并将镜像 URL 写入其中（每行一个）。"
  exit 1
fi

echo "📖 正在读取 $MIRROR_FILE ..."

# 读取文件内容到数组 (自动去除空行和 Windows 换行符)
mirrors=()
while IFS= read -r line || [[ -n "$line" ]]; do
  # 去除首尾空格和回车符
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
  # 跳过空行和以 # 开头的注释行
  if [[ -n "$line" && ! "$line" =~ ^# ]]; then
    mirrors+=("$line")
  fi
done < "$MIRROR_FILE"

# 检查是否有读取到镜像
if [ ${#mirrors[@]} -eq 0 ]; then
  echo "❌ 错误: $MIRROR_FILE 中没有有效的镜像 URL。"
  exit 1
fi

temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# 初始化数组
valid_mirrors=()
failed_mirrors=()

echo "🔍 开始测试 ${#mirrors[@]} 个镜像源..."
echo "------------------------------------------------"

# 测试每个镜像源
for mirror in "${mirrors[@]}"; do
  # 去除末尾可能存在的 /
  mirror=${mirror%/}
  
  printf "Testing %-40s " "$mirror..."
  
  start_time=$(date +%s%3N)
  # 这里增加了 --connect-timeout 防止卡顿太久
  curl -s --connect-timeout 2 --max-time 4 "$mirror/v2/" > /dev/null
  
  if [ $? -eq 0 ]; then
    end_time=$(date +%s%3N)
    time_taken=$((end_time - start_time))
    echo -e "\033[32m[OK] ${time_taken}ms\033[0m" # 绿色显示成功
    echo "$time_taken $mirror" >> "$temp_file"
    valid_mirrors+=("$mirror")
  else
    echo -e "\033[31m[FAILED]\033[0m" # 红色显示失败
    failed_mirrors+=("$mirror")
  fi
done

echo "------------------------------------------------"

# 如果没有有效的镜像源，停止操作
if [ ${#valid_mirrors[@]} -eq 0 ]; then
  echo "❌ 所有镜像源均无法连接，未修改 Docker 配置。"
else
  # 排序并提取有效的镜像源
  sorted_mirrors=$(sort -n "$temp_file" | awk '{print $2}')
  
  # 生成 JSON 格式字符串
  mirrors_json=$(echo "$sorted_mirrors" | awk '{print "\"" $1 "\""}' | paste -sd "," -)

  # Docker 配置内容
  docker_config_content="{\n  \"registry-mirrors\": [\n    $mirrors_json\n  ]\n}"

  # 写入 Docker 配置文件
  echo -e "\n📝 正在写入 /etc/docker/daemon.json ..."
  echo -e "$docker_config_content" | sudo tee /etc/docker/daemon.json > /dev/null

  # 输出有效镜像源 (按速度排序)
  echo -e "\n✅ 已配置的有效镜像源 (按速度排序)："
  # 这里为了美观，重新读取一下排序后的结果
  sort -n "$temp_file" | while read -r time url; do
     echo " - $url (${time}ms)"
  done

  # 重启 Docker 服务
  echo -e "\n🔁 正在重启 Docker..."
  if sudo service docker restart; then
    echo "🚀 Docker 重启成功，镜像源已更新。"
  else
    echo "❌ Docker 重启失败！请检查系统日志。" >&2
  fi
fi

# --- 重点：输出失败的列表供用户修改 ---
if [ ${#failed_mirrors[@]} -gt 0 ]; then
  echo -e "\n========================================"
  echo -e "⚠️  以下镜像源连接失败 (建议从 $MIRROR_FILE 中删除/更新)："
  echo -e "========================================"
  for fail in "${failed_mirrors[@]}"; do
    echo "$fail"
  done
  echo -e "========================================\n"
fi
