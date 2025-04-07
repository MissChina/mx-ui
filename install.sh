#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

# 检查系统
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    else
        echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
    fi
    echo "系统版本: ${release}"
}

# 检查系统架构
check_arch() {
    arch=$(arch)
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        arch="arm64"
    elif [[ $arch == "s390x" ]]; then
        arch="s390x"
    else
        arch="amd64"
        echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
    fi
    echo "系统架构: ${arch}"
}

# 检查操作系统版本
check_os_version() {
    if [[ -f /etc/os-release ]]; then
        os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
    fi
    if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
        os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
    fi

    if [[ x"${release}" == x"centos" ]]; then
        if [[ ${os_version} -le 6 ]]; then
            echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
        fi
    elif [[ x"${release}" == x"ubuntu" ]]; then
        if [[ ${os_version} -lt 16 ]]; then
            echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
        fi
    elif [[ x"${release}" == x"debian" ]]; then
        if [[ ${os_version} -lt 8 ]]; then
            echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
        fi
    fi
}

# 安装依赖
install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt-get update && apt-get install wget curl tar -y
    fi
}

# 安装后配置
config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要设置面板端口、用户名和密码${plain}"
    
    # 随机生成用户名和密码
    random_username=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 8 | head -n 1)
    random_password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)
    
    read -p "是否设置自定义用户名和密码? (y/n, 默认: n): " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置面板用户名 (默认: admin): " config_username
        [[ -z "${config_username}" ]] && config_username="admin"
        read -p "请设置面板密码 (默认: admin): " config_password
        [[ -z "${config_password}" ]] && config_password="admin"
    else
        config_username=${random_username}
        config_password=${random_password}
        echo -e "${green}已设置随机用户名: ${config_username}，密码: ${config_password}${plain}"
    fi

    read -p "请设置面板访问端口 (默认: 54321): " config_port
    [[ -z "${config_port}" ]] && config_port="54321"
    
    # 配置服务
    /usr/local/mx-ui/mx-ui setting -username ${config_username} -password ${config_password}
    /usr/local/mx-ui/mx-ui setting -port ${config_port}
    
    # 显示设置信息
    echo -e "\n${green}mx-ui 面板配置信息：${plain}"
    echo -e "用户名: ${config_username}"
    echo -e "密码: ${config_password}"
    echo -e "面板访问端口: ${config_port}"
}

# 安装mx-ui
install_mx_ui() {
    systemctl stop mx-ui 2>/dev/null
    
    mkdir -p /usr/local/mx-ui/

    if [ $# -gt 0 ]; then
        last_version=$1
        url="https://github.com/MissChina/mx-ui/releases/download/${last_version}/mx-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 mx-ui $1"
    else
        echo -e "开始安装 mx-ui 最新版本"
        url="https://github.com/MissChina/mx-ui/releases/download/v1.0.0/mx-ui-linux-${arch}.tar.gz"
        last_version="v1.0.0"
    fi

    echo -e "从 ${url} 下载 mx-ui"
    wget -N --no-check-certificate -O /usr/local/mx-ui-linux-${arch}.tar.gz ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 mx-ui 失败，请确保你的服务器能够下载 Github 的文件${plain}"
        exit 1
    fi

    tar zxvf mx-ui-linux-${arch}.tar.gz -C /usr/local/
    rm mx-ui-linux-${arch}.tar.gz -f
    cd /usr/local/mx-ui
    chmod +x mx-ui bin/xray-linux-${arch}
    cp -f mx-ui.service /etc/systemd/system/
    
    # 创建软链接
    ln -sf /usr/local/mx-ui/mx-ui /usr/bin/mx-ui
    
    # 配置服务
    config_after_install

    # 启动服务
    systemctl daemon-reload
    systemctl enable mx-ui
    systemctl start mx-ui
    
    echo -e "${green}mx-ui v${last_version}${plain} 安装完成，面板已启动"
    echo -e ""
    echo -e "mx-ui 管理脚本使用方法: "
    echo -e "------------------------------------------"
    echo -e "mx-ui              - 显示管理菜单"
    echo -e "mx-ui start        - 启动 mx-ui 面板"
    echo -e "mx-ui stop         - 停止 mx-ui 面板"
    echo -e "mx-ui restart      - 重启 mx-ui 面板"
    echo -e "mx-ui status       - 查看 mx-ui 状态"
    echo -e "mx-ui enable       - 设置 mx-ui 开机自启"
    echo -e "mx-ui disable      - 取消 mx-ui 开机自启"
    echo -e "mx-ui log          - 查看 mx-ui 日志"
    echo -e "mx-ui setting      - 查看/修改 mx-ui 配置"
    echo -e "mx-ui update       - 更新 mx-ui 面板"
    echo -e "mx-ui install      - 安装 mx-ui 面板"
    echo -e "mx-ui uninstall    - 卸载 mx-ui 面板"
    echo -e "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
check_system
check_arch
check_os_version
install_base
install_mx_ui $1 