#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#检查是否为root用户
[ $(id -u) != "0" ] && { echo -e "${red}错误：请使用root用户运行此脚本${plain}"; exit 1; }

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
}

# 获取系统架构
get_arch() {
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

# 0: 正在运行, 1: 未运行, 2: 未安装
check_status() {
    if [[ ! -f /etc/systemd/system/mx-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status mx-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

# 检查是否安装
check_installed() {
    if [[ ! -f /etc/systemd/system/mx-ui.service ]]; then
        echo ""
        echo -e "${red}请先安装mx-ui${plain}"
        exit 1
    fi
}

# 获取版本
get_version() {
    if [[ -f /usr/local/mx-ui/mx-ui ]]; then
        echo -n "$(/usr/local/mx-ui/mx-ui -v)"
    else
        echo -e "${red}未安装mx-ui${plain}"
        exit 1
    fi
}

# 显示菜单
show_menu() {
    echo -e "
  ${green}mx-ui 管理脚本${plain}
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 安装 mx-ui
  ${green}2.${plain} 更新 mx-ui
  ${green}3.${plain} 卸载 mx-ui
————————————————
  ${green}4.${plain} 启动 mx-ui
  ${green}5.${plain} 停止 mx-ui
  ${green}6.${plain} 重启 mx-ui
————————————————
  ${green}7.${plain} 查看 mx-ui 状态
  ${green}8.${plain} 查看 mx-ui 日志
————————————————
  ${green}9.${plain} 设置 mx-ui 开机自启
  ${green}10.${plain} 取消 mx-ui 开机自启
————————————————
  ${green}11.${plain} 修改用户名和密码
  ${green}12.${plain} 修改面板端口
  ${green}13.${plain} 显示当前设置
 "
    show_status
    echo && read -p "请输入选择 [0-13]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) install
        ;;
        2) update
        ;;
        3) uninstall
        ;;
        4) start
        ;;
        5) stop
        ;;
        6) restart
        ;;
        7) show_status
        ;;
        8) view_log
        ;;
        9) enable
        ;;
        10) disable
        ;;
        11) modify_user
        ;;
        12) modify_port
        ;;
        13) show_settings
        ;;
        *) echo -e "${red}请输入正确的数字 [0-13]${plain}"
        ;;
    esac
}

# 显示状态
show_status() {
    check_status
    case $? in
        0)
            echo -e "mx-ui状态: ${green}已运行${plain}"
            echo -e "当前版本: $(get_version)"
            ;;
        1)
            echo -e "mx-ui状态: ${yellow}未运行${plain}"
            echo -e "当前版本: $(get_version)"
            ;;
        2)
            echo -e "mx-ui状态: ${red}未安装${plain}"
    esac
}

# 安装
install() {
    bash <(curl -Ls https://github.com/MissChina/mx-ui/raw/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

# 更新
update() {
    if [[ $# == 0 ]]; then
        echo && echo -e "输入版本号，例如：${green}v1.0.1${plain}"
        read -p "请输入版本号: " VERSION
        if [[ -z "${VERSION}" ]]; then
            echo -e "${red}错误：版本号不能为空${plain}"
            exit 1
        fi
    else
        VERSION=$1
    fi
    
    bash <(curl -Ls https://github.com/MissChina/mx-ui/raw/master/install.sh) $VERSION
    if [[ $? == 0 ]]; then
        echo -e "${green}更新完成，已自动重启 mx-ui${plain}"
        exit 0
    fi
    
    echo -e "${red}更新 mx-ui 失败，请检查错误日志${plain}"
}

# 卸载
uninstall() {
    echo -e "确定要卸载 mx-ui 吗？(y/n): "
    read -p "" answer
    if [[ "${answer}" != "y" ]]; then
        exit 0
    fi
    
    systemctl stop mx-ui
    systemctl disable mx-ui
    rm /etc/systemd/system/mx-ui.service -f
    systemctl daemon-reload
    
    rm -rf /usr/local/mx-ui/
    rm /usr/bin/mx-ui -f
    
    echo -e "${green}mx-ui 已成功卸载${plain}"
}

# 启动
start() {
    check_installed
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}mx-ui 已经在运行，无需再次启动${plain}"
        exit 1
    fi
    
    systemctl start mx-ui
    echo -e "${green}mx-ui 启动成功${plain}"
}

# 停止
stop() {
    check_installed
    check_status
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${green}mx-ui 已经停止，无需再次停止${plain}"
        exit 1
    fi
    
    systemctl stop mx-ui
    echo -e "${green}mx-ui 停止成功${plain}"
}

# 重启
restart() {
    check_installed
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}mx-ui 未安装，请先安装${plain}"
        exit 1
    fi
    
    systemctl restart mx-ui
    echo -e "${green}mx-ui 重启成功${plain}"
}

# 启用
enable() {
    check_installed
    systemctl enable mx-ui
    echo -e "${green}设置 mx-ui 开机自启成功${plain}"
}

# 禁用
disable() {
    check_installed
    systemctl disable mx-ui
    echo -e "${green}取消 mx-ui 开机自启成功${plain}"
}

# 查看日志
view_log() {
    check_installed
    if [[ -f /usr/local/mx-ui/mx-ui.log ]]; then
        cat /usr/local/mx-ui/mx-ui.log
    elif [[ -f /root/.config/mx-ui/mx-ui.log ]]; then
        cat /root/.config/mx-ui/mx-ui.log
    else
        echo -e "${red}日志文件不存在${plain}"
    fi
}

# 修改用户和密码
modify_user() {
    check_installed
    read -p "设置新的用户名: " username
    read -p "设置新的密码: " password
    if [[ -z "${username}" || -z "${password}" ]]; then
        echo -e "${red}用户名和密码不能为空${plain}"
        exit 1
    fi
    
    /usr/local/mx-ui/mx-ui setting -username "${username}" -password "${password}"
    echo -e "${green}用户名和密码已修改，请重启面板生效${plain}"
}

# 修改端口
modify_port() {
    check_installed
    read -p "设置新的面板端口: " port
    if [[ -z "${port}" ]]; then
        echo -e "${red}面板端口不能为空${plain}"
        exit 1
    fi
    
    /usr/local/mx-ui/mx-ui setting -port ${port}
    echo -e "${green}面板端口已修改为 ${port}，请重启面板生效${plain}"
}

# 显示设置
show_settings() {
    check_installed
    /usr/local/mx-ui/mx-ui setting -show
}

# 主函数
main() {
    check_system
    get_arch
    
    if [[ $# > 0 ]]; then
        case $1 in
            "start") start
            ;;
            "stop") stop
            ;;
            "restart") restart
            ;;
            "status")
                check_status
                case $? in
                    0) echo -e "${green}mx-ui 正在运行${plain}"
                    ;;
                    1) echo -e "${yellow}mx-ui 未运行${plain}"
                    ;;
                    2) echo -e "${red}mx-ui 未安装${plain}"
                    ;;
                esac
            ;;
            "enable") enable
            ;;
            "disable") disable
            ;;
            "log") view_log
            ;;
            "update") update $2
            ;;
            "install") install $2
            ;;
            "uninstall") uninstall
            ;;
            "setting") show_settings
            ;;
            *) show_menu
        esac
    else
        show_menu
    fi
}

main "$@" 