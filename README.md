# docker_proxy
一个小小的配置docker镜像的实用脚本,解决国内无法拉取镜像的头疼问题


-----

# Docker 镜像源自动测速与配置工具

这是一个用于 Linux 环境的 Bash 脚本，旨在自动化 Docker 镜像源的优选与配置过程。它从外部配置文件读取镜像地址，并发进行连接测试，自动将速度最快的源写入 Docker 配置，同时筛选出失效的源以便清理。

## 功能特点

  * **外部配置**：从同目录下的 `mirrors.txt` 读取 URL，方便管理，无需修改脚本代码。
  * **智能测速**：自动测试连接延迟，过滤掉无法连接的源。
  * **自动配置**：根据测速结果，将有效源按响应速度排序写入 `/etc/docker/daemon.json`。
  * **服务重启**：自动重启 Docker 服务以应用更改。
  * **失效反馈**：脚本运行结束后，列出所有连接失败的 URL，方便用户维护源列表。
  * **格式兼容**：自动处理 Windows/Linux 换行符差异，支持 `#` 注释。

##  前置要求

  * Linux 操作系统 (CentOS, Ubuntu, Debian 等)
  * 已安装 Docker
  * 拥有 `sudo` 权限 (需要修改系统配置和重启服务)
  * 系统已安装 `curl`

##  目录结构

在使用前，请确保你的文件目录结构如下：

```text
.
├── update_mirrors.sh   # 主脚本文件
└── mirrors.txt         # 镜像源配置文件
```

##  快速开始

### 1\. 创建配置文件

在脚本同级目录下创建名为 `mirrors.txt` 的文件，并将你的镜像源地址写入其中（一行一个）。

**示例 `mirrors.txt` 内容：**

```text
https://docker.1ms.run
https://docker.xuanyuan.me
# 这是一个注释，下面这个不想测了
# https://slow-mirror.example.com
https://docker.m.daocloud.io
https://hub.rat.dev
```

### 2\. 准备脚本

将脚本内容保存为 `update_mirrors.sh`，并赋予执行权限：

```bash
chmod +x update_mirrors.sh
```

### 3\. 运行脚本

执行脚本（脚本内部包含 sudo 操作，运行过程中可能需要输入密码）：

```bash
./update_mirrors.sh
```

##  输出示例

运行脚本后，你将看到类似以下的输出：

```text
📖 正在读取 mirrors.txt ...
🔍 开始测试 5 个镜像源...
------------------------------------------------
Testing https://docker.1ms.run...            [OK] 120ms
Testing https://docker.xuanyuan.me...        [OK] 450ms
Testing https://bad.example.com...           [FAILED]
Testing https://docker.m.daocloud.io...      [OK] 89ms
...
------------------------------------------------

📝 正在写入 /etc/docker/daemon.json ...

✅ 已配置的有效镜像源 (按速度排序)：
 - https://docker.m.daocloud.io (89ms)
 - https://docker.1ms.run (120ms)
 - https://docker.xuanyuan.me (450ms)

🔁 正在重启 Docker...
🚀 Docker 重启成功，镜像源已更新。

========================================
⚠️  以下镜像源连接失败 (建议从 mirrors.txt 中删除/更新)：
========================================
https://bad.example.com
========================================
```
<img width="560" height="586" alt="image" src="https://github.com/user-attachments/assets/8b6b14f6-215c-41eb-bcc2-09586529868e" />

## ⚙️ 高级配置 (可选)

如果你需要调整超时时间，可以修改脚本中的 `curl` 参数：

```bash
# --connect-timeout: 连接超时时间 (秒)
# --max-time: 最大总操作时间 (秒)
curl -s --connect-timeout 2 --max-time 4 "$mirror/v2/" > /dev/null
```

## ⚠️ 注意事项

1.  **覆盖风险**：脚本会**覆盖**现有的 `/etc/docker/daemon.json` 文件中的 `registry-mirrors` 配置。如果你有该文件有其他复杂配置（如 `insecure-registries` 或 `log-driver`），请先备份该文件。
2.  **Sudo 权限**：由于涉及修改 `/etc` 下的文件和重启系统服务，脚本必须在有 sudo 权限的用户下运行。

## 📋 维护建议

每次运行完脚本后，请查看底部的 **"以下镜像源连接失败"** 列表。建议定期将 `mirrors.txt` 中长期失败的 URL 删除，以加快下次脚本运行的速度。
