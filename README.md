# docker_proxy
小小的配置docker镜像的实用脚本,解决国内无法拉取镜像的头疼问题


-----

# Docker 网络优化工具箱

本项目包含两个 Bash 脚本，分别用于解决 Docker 在国内网络环境下的两大难题：

1.  **镜像下载慢/连接超时**：通过 `update_mirrors.sh` 自动测速并优选国内镜像源。
2.  **Docker Search 失败/完全无法连接**：通过 `docker_proxy.sh` 为 Docker 守护进程配置网络代理。

## 📂 目录结构建议

为了方便管理，建议将脚本和配置文件组织在同一目录下：

```text
.
├── docker_yuan.sh    # [脚本1] 镜像源测速与自动配置
├── mirrors.txt          # [配置1] 镜像源 URL 列表
├── docker_proxy.sh      # [脚本2] 代理管理工具
└── proxies.txt          # [配置2] 代理节点列表
```

## 🛠️ 初始化

首次使用前，请赋予脚本执行权限：

```bash
chmod +x docker_yuan.sh docker_proxy.sh
```

-----

## 🚀 工具一：镜像源自动测速 (update\_mirrors.sh)

**适用场景**：`docker pull` 速度慢，或者某些特定的国内加速器失效。该脚本会自动测试连通性，将最快的源写入配置。

### 1\. 配置文件 (`mirrors.txt`)

在同目录下创建 `mirrors.txt`，写入你收集的镜像源地址（一行一个）。

```text
https://docker.1ms.run
https://docker.xuanyuan.me
# 支持注释，这行不会被读取
https://docker.m.daocloud.io
```

### 2\. 使用方法

直接运行脚本（需要 sudo 权限）：

```bash
sudo ./docker_yuan.sh
```
<img width="560" height="586" alt="image" src="https://github.com/user-attachments/assets/8b6b14f6-215c-41eb-bcc2-09586529868e" />

### 3\. 功能特性

  * **自动测速**：并发测试列表中的 URL，按响应时间排序。
  * **智能筛选**：自动剔除无法连接的死链。
  * **结果反馈**：脚本运行结束后，会列出**失效的 URL**，方便你维护 `mirrors.txt`。

#### ⚠️ 注意事项
   1.  **覆盖风险**：脚本会**覆盖**现有的 `/etc/docker/daemon.json` 文件中的 `registry-mirrors` 配置。如果你有该文件有其他复杂配置（如 `insecure-registries` 或 `log-driver`），请先备份该文件。
   2.  **Sudo 权限**：由于涉及修改 `/etc` 下的文件和重启系统服务，脚本必须在有 sudo 权限的用户下运行。

-----

## 🌐 工具二：Docker 代理管理 (docker\_proxy.sh)

注意:需要结合自己的代理使用,当你发现无法连接代理时,注意观察防火墙

**适用场景**：`docker search` 命令报错、需要拉取被完全屏蔽的镜像（如 gcr.io, quay.io），或所有国内镜像源都失效时。

### 1\. 配置文件 (`proxies.txt`)

在同目录下创建 `proxies.txt`，格式为 `协议://IP:端口 # 备注`。

```text
http://127.0.0.1:7890 # 本地 Clash
socks5://192.168.1.5:1080 # 局域网节点
http://user:pass@89.46.223.201:3128 # 外部付费节点
```

### 2\. 使用方法

#### 交互式菜单（推荐）

不带参数运行，进入选择菜单：

```bash
sudo ./docker_proxy.sh
```

  * 选择数字启用对应代理。
  * 选择 `0` 关闭代理。

#### 命令行快捷模式

  * **关闭代理**：
    ```bash
    sudo ./docker_proxy.sh off
    ```
  * **启用列表中的第 N 个代理**：
    ```bash
    sudo ./docker_proxy.sh 1
    ```
<img width="868" height="401" alt="image" src="https://github.com/user-attachments/assets/507a4b46-8226-4ba7-b380-ca63912fb093" />

### 3\. 功能特性

  * **连通性预检**：应用代理前会自动测试该节点是否能连通 Google，防止配置无效代理导致 Docker 失联。
  * **无残留切换**：切换或关闭代理时会自动重载 daemon 并重启 Docker 服务。








