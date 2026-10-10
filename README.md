# VPS Bootstrap

**English | [简体中文](#简体中文)**

A one-command bootstrap for a fresh Debian or Ubuntu VPS. It runs the JINZHI host audit, installs Docker, applies BBR/network tuning, then deploys Cloudflare DDNS with Docker Compose.

## Features

1. Updates APT and installs `curl` and CA certificates.
2. Runs the host audit script.
3. Installs Docker and checks Docker Compose.
4. Applies BBR and network tuning.
5. Deploys `favonia/cloudflare-ddns:1` with your Cloudflare token and domain.

## Requirements and compatibility

- A fresh Debian or Ubuntu VPS using `apt-get` and systemd.
- Root access and an internet connection.
- A Cloudflare API token for the zone that contains your DDNS record.
- Debian 13 is detected and allowed to continue, but the upstream BBR script does not currently list Debian 13 as a supported release. Compatibility is therefore not confirmed. On container-based VPS plans, kernel settings such as BBR may be unavailable.
- The Docker installer checks the Debian/Ubuntu family, then uses Docker's convenience installer and an APT fallback for the Compose plugin. It does not check individual release versions itself.

## Install

Log in to the VPS as `root` and run this command in Bash. Replace the example token and domain with your own:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/krililrify/vps-bootstrap/main/install.sh) 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com'
```

To enable IPv6 record management, add `ipv6`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/krililrify/vps-bootstrap/main/install.sh) 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com' ipv6
```

The token is passed as a command-line argument. Your shell may save the command in its history, and the argument may briefly be visible in the process list. Use a narrowly scoped Cloudflare token, and do not put a real token in this repository, screenshots, or public issues.

## What the installer changes

- **`/etc/hosts`:** the audit script saves a backup under `/etc/hosts.backup/`, then writes its blocklist to `/etc/hosts`. Review the upstream list before installing: it maps many domains to localhost, including some package tracker hosts. To restore a backup, first list the available copies and then choose the desired file:

  ```bash
  ls -lt /etc/hosts.backup/
  cp -a /etc/hosts.backup/hosts.YYYYMMDD_HHMMSS /etc/hosts
  ```

- **System packages and Docker:** APT is updated, `curl` and CA certificates are installed, and Docker is installed or started. Docker Compose is required for DDNS.
- **Network settings:** the BBR script writes persistent kernel/network tuning, may create up to 512 MB of swap if none exists, and changes system tuning files. This installer sets `ENABLE_FORWARD=0`; IP forwarding is not enabled by default.
- **Cloudflare DDNS:** configuration is stored in `/opt/cloudflare-ddns/.env` with permissions `600`. The Compose files are under `/opt/cloudflare-ddns`.
- **Rerunning:** rerunning the installer replaces the DDNS token/domain configuration and recreates the DDNS container. Do not rerun it on an existing DDNS setup unless you intend to replace that configuration.
- The installer does not reboot the VPS.

Review the scripts before running them as root. This project downloads the host-audit, Docker, and BBR scripts from their upstream `main` branches, so upstream changes can affect later runs. For repeatable deployments, review and pin upstream script versions or commits before relying on this installer in production.

## Manage DDNS

```bash
cd /opt/cloudflare-ddns && docker compose logs -f
cd /opt/cloudflare-ddns && docker compose restart
cd /opt/cloudflare-ddns && docker compose down
```

## Upstream scripts

- [JINZHI host audit](https://github.com/krililrify/jinzhi)
- [Docker installer](https://github.com/newxqkjfenxiang/docker-install)
- [BBR/network tuning](https://github.com/krililrify/bbr)
- [Cloudflare DDNS image](https://github.com/favonia/cloudflare-ddns)

---

# 简体中文

这是一个用于 Debian 或 Ubuntu 新 VPS 的一键初始化脚本。它会运行主机审计、安装 Docker、应用 BBR/网络优化，然后通过 Docker Compose 部署 Cloudflare DDNS。

## 功能

1. 更新 APT 软件包索引，并安装 `curl` 和 CA 证书。
2. 运行主机审计脚本。
3. 安装 Docker 并检查 Docker Compose。
4. 应用 BBR 和网络参数优化。
5. 使用你的 Cloudflare Token 和域名部署 `favonia/cloudflare-ddns:1`。

## 要求与兼容性

- Debian 或 Ubuntu，使用 `apt-get` 和 systemd。
- 需要 root 权限和可用的网络连接。
- 需要一个可管理 DDNS 域名所在 Zone 的 Cloudflare API Token。
- Debian 13 可以被识别并继续执行，但 BBR 上游脚本目前没有把 Debian 13 列为支持版本，因此兼容性尚未确认。容器类 VPS 可能无法应用 BBR 等内核设置。
- Docker 安装脚本会检查 Debian/Ubuntu 系统类型，并调用 Docker 官方便捷安装脚本；若 Compose 插件缺失，会尝试通过 APT 安装。它没有单独检查发行版版本号。

## 安装命令

先 SSH 登录 VPS，并以 `root` 身份在 Bash 中运行。将示例 Token 和域名替换成你自己的：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/krililrify/vps-bootstrap/main/install.sh) 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com'
```

如果要管理 IPv6 记录，在命令末尾添加 `ipv6`：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/krililrify/vps-bootstrap/main/install.sh) 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com' ipv6
```

Token 会作为命令行参数传给脚本。Shell 可能会把整条命令记录到历史中，Token 也可能短暂出现在进程列表里。建议使用权限范围尽可能小的 Cloudflare Token。不要把真实 Token 提交到仓库、截图或公开问题中。

## 脚本会修改什么

- **`/etc/hosts`：**主机审计脚本会先把原文件备份到 `/etc/hosts.backup/`，再写入域名屏蔽列表。请先检查上游名单：名单中的许多域名会被解析到本机，其中也包括一些软件包 tracker 域名。需要恢复时，先查看备份，再选择一个文件恢复：

  ```bash
  ls -lt /etc/hosts.backup/
  cp -a /etc/hosts.backup/hosts.YYYYMMDD_HHMMSS /etc/hosts
  ```

- **系统软件和 Docker：**更新 APT，安装 `curl` 和 CA 证书，并安装或启动 Docker。DDNS 部署需要 Docker Compose。
- **网络设置：**BBR 脚本会写入持久化的内核/网络参数；如果系统没有 swap，可能创建最多 512 MB 的 swap，并修改系统调优配置。本整合脚本默认设置 `ENABLE_FORWARD=0`，不会开启 IP 转发。
- **Cloudflare DDNS：**配置保存在 `/opt/cloudflare-ddns/.env`，权限为 `600`；Compose 文件也放在 `/opt/cloudflare-ddns`。
- **重复运行：**再次运行会替换 DDNS 的 Token/域名配置，并重建 DDNS 容器。如果你已有 DDNS 配置，只有在确认要替换时再运行。
- 脚本不会自动重启 VPS。

请先阅读脚本，再以 root 执行。本项目会从各上游仓库的 `main` 分支下载主机审计、Docker 和 BBR 脚本，因此上游后续更新可能改变实际执行内容。若要稳定、可复现地部署，建议先审核并固定上游脚本的版本或 commit。

## DDNS 常用管理命令

```bash
cd /opt/cloudflare-ddns && docker compose logs -f
cd /opt/cloudflare-ddns && docker compose restart
cd /opt/cloudflare-ddns && docker compose down
```

## 上游项目

- [JINZHI 主机审计](https://github.com/krililrify/jinzhi)
- [Docker 安装脚本](https://github.com/newxqkjfenxiang/docker-install)
- [BBR/网络优化](https://github.com/krililrify/bbr)
- [Cloudflare DDNS 镜像](https://github.com/favonia/cloudflare-ddns)
