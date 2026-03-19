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
# 使用 mktemp 创建一个临时文件来存放排序信息
# 使用 trap 确保脚本退出时临时文件被删除，无论成功还是失败
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
  
  # 使用 curl 内置的时间统计功能（微秒级精度，兼容性好）
  # 这里增加了 --connect-timeout 防止卡顿太久，使用 /v2/ 标准 endpoint
  curl_result=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" --connect-timeout 2 --max-time 4 "$mirror/v2/")
  http_code=$(echo "$curl_result" | cut -d',' -f1)
  time_total=$(echo "$curl_result" | cut -d',' -f2)
  
  # 检查 HTTP 状态码是否为 200 或 401（Docker registry 未授权也是正常的）
  if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
    # 将秒转换为毫秒（保留整数）
    time_taken=$(echo "$time_total * 1000 / 1" | bc 2>/dev/null || echo "0")
    echo -e "\033[32m[OK] ${time_taken}ms\033[0m" # 绿色显示成功
    echo "$time_taken $mirror" >> "$temp_file"
    valid_mirrors+=("$mirror")
  else
    echo -e "\033[31m[FAILED]\033[0m" # 红色显示失败
    failed_mirrors+=("$mirror")
  fi
done

echo "------------------------------------------------"

# --- 关键修改：处理镜像排序和文件重写 ---

# 1. 初始化最终写入文件的内容变量
NEW_MIRRORS_CONTENT=""

# 如果有有效的镜像源，则进行排序和配置写入
if [ ${#valid_mirrors[@]} -gt 0 ]; then
  # 排序并提取有效的镜像源
  # 使用 sort -n "$temp_file" 按时间排序，awk '{print $2}' 提取 URL
  sorted_mirrors=$(sort -n "$temp_file" | awk '{print $2}')
  
  # 将排序后的 URL 列表格式化为每行一个字符串，并添加到最终内容
  NEW_MIRRORS_CONTENT+="$(echo "$sorted_mirrors")\n"

  # 生成 JSON 格式字符串
  mirrors_json=$(echo "$sorted_mirrors" | awk '{print "\"" $1 "\""}' | paste -sd "," -)

  # Docker 配置内容
  docker_config_content="{\n  \"registry-mirrors\": [\n    $mirrors_json\n  ]\n}"

  # 写入 Docker 配置文件 (需要 sudo 权限)
  echo -e "\n📝 正在写入 /etc/docker/daemon.json ..."
  echo -e "$docker_config_content" | sudo tee /etc/docker/daemon.json > /dev/null

  # 输出有效镜像源 (按速度排序)
  echo -e "\n✅ 已配置的有效镜像源 (按速度排序)："
  # 这里为了美观，重新读取一下排序后的结果
  sort -n "$temp_file" | while read -r time url; do
    echo " - $url (${time}ms)"
  done

  # 重启 Docker 服务 (需要 sudo 权限)
  echo -e "\n🔁 正在重启 Docker..."
  if sudo service docker restart; then
    echo "🚀 Docker 重启成功，镜像源已更新。"
  else
    echo "❌ Docker 重启失败！请检查系统日志。" >&2
  fi

else
  echo "❌ 所有镜像源均无法连接，未修改 Docker 配置。"
fi

# 2. 将失败的镜像源追加到最终内容（排在末尾）
if [ ${#failed_mirrors[@]} -gt 0 ]; then
  echo -e "\n========================================"
  echo -e "⚠️  以下镜像源连接失败 (已移至 $MIRROR_FILE 末尾)："
  echo -e "========================================"
  for fail in "${failed_mirrors[@]}"; do
    echo "$fail"
    NEW_MIRRORS_CONTENT+="$fail\n"
  done
  echo -e "========================================\n"
fi

# 3. 覆盖写入 MIRROR_FILE
# 使用 echo -e 命令处理 NEW_MIRRORS_CONTENT 中的换行符，并覆盖原文件
if [ -n "$NEW_MIRRORS_CONTENT" ]; then
    # 由于 NEW_MIRRORS_CONTENT 是通过字符串拼接构建的，最后会多一个 \n
    # 这里使用 echo -e "..." 配合 sed 来处理末尾的换行符，并覆盖文件
    # 注意：这里不需要 sudo，因为 mirros.txt 是用户文件
    echo -e "$NEW_MIRRORS_CONTENT" | sed '$d' > "$MIRROR_FILE"
    echo "💾 文件 '$MIRROR_FILE' 已更新：成功的镜像源按速度排在前面，失败的排在末尾。"
fi
