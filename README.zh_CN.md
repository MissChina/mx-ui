# MX-UI 面板

MX-UI 是一个基于 Xray 核心的 Web 管理面板，提供直观、简单易用的图形界面，帮助用户更便捷地配置和管理 Xray 服务。本项目参考了 [vaxilu/x-ui](https://github.com/vaxilu/x-ui) 和 [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) 项目，使用 [XTLS/Xray-core](https://github.com/XTLS/Xray-core) 作为核心。

## 功能特点

- 支持面板用户管理
- 支持多种协议配置
- 支持流量统计和限制
- 支持自定义配置模板
- 支持多用户多协议配置
- 支持订阅链接生成
- 支持多种系统架构（amd64、arm64、s390x）
- 支持中文界面

## 安装指南

### Linux 一键安装脚本

```bash
bash <(curl -Ls https://github.com/MissChina/mx-ui/raw/master/install.sh)
```

### Windows 安装

1. 从 [Release 页面](https://github.com/MissChina/mx-ui/releases) 下载最新的 Windows 版本安装包
2. 解压缩下载的文件
3. 以管理员身份运行 `install_windows.bat` 脚本
4. 按照提示完成安装

### 手动安装（Linux）

1. 首先下载最新的程序包：

```bash
wget https://github.com/MissChina/mx-ui/releases/download/v1.0.0/mx-ui-linux-amd64.tar.gz
```

2. 解压程序包并进入目录：

```bash
tar zxvf mx-ui-linux-amd64.tar.gz -C /usr/local/
cd /usr/local/mx-ui/
```

3. 赋予程序执行权限：

```bash
chmod +x mx-ui bin/xray-linux-amd64
```

4. 安装服务：

```bash
cp -f mx-ui.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable mx-ui
systemctl start mx-ui
```

## 系统要求

### Linux
- CentOS 7+
- Ubuntu 16+
- Debian 8+
- 内存: 最低128MB
- 存储: 最低10MB可用空间
- 处理器: 支持64位指令集

### Windows
- Windows 7 SP1 或更高版本
- 64位操作系统
- 内存: 最低256MB
- 存储: 最低20MB可用空间

## 管理命令（Linux）

安装完成后，可以使用以下命令管理面板：

```bash
mx-ui              # 显示管理菜单
mx-ui start        # 启动面板
mx-ui stop         # 停止面板
mx-ui restart      # 重启面板
mx-ui status       # 查看面板状态
mx-ui enable       # 设置开机自启
mx-ui disable      # 取消开机自启
mx-ui log          # 查看面板日志
mx-ui setting      # 查看/修改面板配置
mx-ui update       # 更新面板
mx-ui install      # 安装面板
mx-ui uninstall    # 卸载面板
```

## Windows 服务管理

在 Windows 系统中，可以通过服务管理器管理 mx-ui 服务：

1. 按下 `Win + R` 键，输入 `services.msc` 并回车
2. 在服务列表中找到 "MX-UI Panel" 服务
3. 右键点击服务，选择启动、停止或重启

## 更新历史

### v1.0.0 (2023-04-07)
- 首次发布
- 支持基本的面板功能
- 支持用户管理和Xray配置
- 支持Linux和Windows系统

## 常见问题

### 1. 如何修改面板端口？

Linux系统：
```bash
mx-ui setting -port 新端口
systemctl restart mx-ui
```

Windows系统：
在服务管理器中重启服务，或在命令提示符中运行：
```cmd
sc stop mx-ui
sc start mx-ui
```

### 2. 忘记面板密码怎么办？

Linux系统：
```bash
mx-ui setting -username 新用户名 -password 新密码
systemctl restart mx-ui
```

Windows系统：
编辑 `%USERPROFILE%\mx-ui\settings.json` 文件，修改 username 和 password 字段，然后重启服务。

## 许可协议

本项目使用 MIT 许可证，详情请参阅 [LICENSE](LICENSE) 文件。

## 贡献指南

欢迎提交问题报告和功能请求，如果您想要贡献代码，请先 Fork 本仓库并提交 Pull Request。

## 致谢

- [vaxilu/x-ui](https://github.com/vaxilu/x-ui)
- [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui)
- [XTLS/Xray-core](https://github.com/XTLS/Xray-core)

## 联系方式

GitHub: [https://github.com/MissChina](https://github.com/MissChina) 