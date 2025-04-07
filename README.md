# MX-UI

MX-UI 是一个基于Web的XRay面板，用于管理XRay服务器。它提供了直观的用户界面，让您可以轻松管理XRay配置、监控系统状态和流量统计。

## 主要功能

- 系统状态监控（CPU、内存、磁盘、网络等）
- XRay 版本管理与切换
- 入站连接管理
- 客户端配置管理
- 流量统计
- 界面美观，支持响应式设计

## 系统要求

- 操作系统：CentOS 7+、Ubuntu 18.04+、Debian 10+
- 架构：x86_64 (amd64)、arm64
- 内存：建议至少 1GB
- 硬盘：建议至少 10GB 可用空间

## 安装

### 快速安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/MissChina/mx-ui/main/install.sh)
```

### 手动安装

如果您想手动控制安装过程，可以先下载脚本，然后按照需要执行：

```bash
wget -O mxui.sh https://raw.githubusercontent.com/MissChina/mx-ui/main/install.sh
chmod +x mxui.sh

# 安装
./mxui.sh install

# 卸载
./mxui.sh uninstall

# 更新
./mxui.sh update

# 查看状态
./mxui.sh status

# 查看帮助信息
./mxui.sh help
```

## 访问面板

安装完成后，可以通过以下地址访问面板：

```
http://服务器IP:54321
```

默认用户名和密码：
- 用户名：admin
- 密码：admin

**首次登录后请立即修改默认密码！**

## 常见问题

### 无法访问面板

1. 检查服务状态：
```bash
./mxui.sh status
```

2. 检查防火墙是否开放了54321端口：
```bash
# CentOS
firewall-cmd --zone=public --add-port=54321/tcp --permanent
firewall-cmd --reload

# Ubuntu/Debian
ufw allow 54321/tcp
ufw reload
```

3. 检查日志文件：
```bash
journalctl -u mx-ui
cat /var/log/mx-ui/access.log
cat /var/log/mx-ui/error.log
```

### 端口被占用

如果54321端口被占用，可以登录后在设置中更改Web端口。

### 服务无法启动

检查日志以获取更多信息：
```bash
journalctl -u mx-ui
```

## 更新日志

### v1.0.0 (2025-04-07)
- 初始版本发布
- 提供XRay服务管理
- 系统状态监控
- 用户认证与管理

## 贡献

欢迎提交Issue和Pull Request来帮助改进MX-UI。在提交PR前，请确保您的代码符合项目的编码规范。

## 许可证

本项目基于MIT许可证。详情请参阅[LICENSE](LICENSE)文件。 