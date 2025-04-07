#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

# 当前脚本版本号
current_version="1.0.0"

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
        echo -e "${red}检测架构失败 $arch ${plain}" && exit 1
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
        yum install wget curl tar git -y
    else
        apt-get update && apt-get install wget curl tar git -y
    fi
}

# 安装Go环境
install_go() {
    echo -e "${green}正在安装Go环境...${plain}"
    
    # 检查是否已安装Go
    if command -v go &>/dev/null; then
        echo -e "${green}Go已安装，跳过安装步骤${plain}"
        return
    fi
    
    # 下载并安装Go
    if [[ $arch == "amd64" ]]; then
        wget -O /tmp/go.tar.gz https://dl.google.com/go/go1.21.0.linux-amd64.tar.gz
    elif [[ $arch == "arm64" ]]; then
        wget -O /tmp/go.tar.gz https://dl.google.com/go/go1.21.0.linux-arm64.tar.gz
    else
        wget -O /tmp/go.tar.gz https://dl.google.com/go/go1.21.0.linux-amd64.tar.gz
    fi
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载Go失败，尝试使用备用链接${plain}"
        if [[ $arch == "amd64" ]]; then
            wget -O /tmp/go.tar.gz https://gomirrors.org/dl/go/go1.21.0.linux-amd64.tar.gz
        elif [[ $arch == "arm64" ]]; then
            wget -O /tmp/go.tar.gz https://gomirrors.org/dl/go/go1.21.0.linux-arm64.tar.gz
        else
            wget -O /tmp/go.tar.gz https://gomirrors.org/dl/go/go1.21.0.linux-amd64.tar.gz
        fi
        
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载Go失败，请手动安装Go环境后重试${plain}"
            return 1
        fi
    fi
    
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    
    # 配置环境变量
    echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
    source /etc/profile.d/go.sh
    export PATH=$PATH:/usr/local/go/bin
    
    echo -e "${green}Go安装完成${plain}"
    go version
}

# 编译mx-ui
compile_mx_ui() {
    echo -e "${green}正在编译mx-ui...${plain}"
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    echo -e "${green}临时目录: ${TEMP_DIR}${plain}"
    
    # 克隆完整源码
    echo -e "${green}克隆源码...${plain}"
    git clone https://github.com/MissChina/mx-ui.git ${TEMP_DIR}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}克隆源码失败，尝试直接下载源码压缩包${plain}"
        rm -rf ${TEMP_DIR}
        TEMP_DIR=$(mktemp -d)
        wget -O ${TEMP_DIR}/source.zip https://github.com/MissChina/mx-ui/archive/refs/heads/main.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载源码失败${plain}"
            return 1
        fi
        unzip -q ${TEMP_DIR}/source.zip -d ${TEMP_DIR}
        mv ${TEMP_DIR}/mx-ui-main/* ${TEMP_DIR}/
        rm -rf ${TEMP_DIR}/mx-ui-main
        rm -f ${TEMP_DIR}/source.zip
    fi
    
    # 进入临时目录编译
    cd ${TEMP_DIR}
    
    # 下载依赖
    echo -e "${green}下载依赖...${plain}"
    export GO111MODULE=on
    export GOPROXY=https://goproxy.cn,direct
    
    # 修复依赖下载问题
    go mod tidy
    if [[ $? -ne 0 ]]; then
        echo -e "${yellow}自动修复依赖失败，尝试手动添加依赖${plain}"
        # 手动安装主要依赖
        go get -u github.com/op/go-logging
        go get -u gorm.io/driver/sqlite
        go get -u gorm.io/gorm
        go get -u github.com/gin-gonic/gin
        go get -u github.com/gin-contrib/sessions
        go get -u github.com/gin-contrib/sessions/cookie
    fi
    
    # 再次尝试修复依赖
    go mod tidy
    
    # 编译
    echo -e "${green}开始编译...${plain}"
    go build -o mx-ui main.go
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}编译mx-ui失败${plain}"
        return 1
    fi
    
    # 复制编译好的二进制文件
    cp mx-ui /usr/local/mx-ui/
    chmod +x /usr/local/mx-ui/mx-ui
    
    # 复制其他必要文件
    cp -rf web /usr/local/mx-ui/
    mkdir -p /usr/local/mx-ui/bin
    
    # 下载xray核心
    echo -e "${green}下载xray核心...${plain}"
    XRAY_VERSION="1.8.6"
    if [[ $arch == "amd64" ]]; then
        wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip
    elif [[ $arch == "arm64" ]]; then
        wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-arm64-v8a.zip
    else
        # 对于其他架构，使用amd64版本
        wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip
    fi
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载xray失败，创建占位符文件${plain}"
        echo "#!/bin/bash" > /usr/local/mx-ui/bin/xray-linux-${arch}
        echo "echo 'Xray core not found. Please install it manually.'" >> /usr/local/mx-ui/bin/xray-linux-${arch}
        chmod +x /usr/local/mx-ui/bin/xray-linux-${arch}
    else
        unzip -q /tmp/xray.zip -d /tmp/xray
        cp /tmp/xray/xray /usr/local/mx-ui/bin/xray-linux-${arch}
        chmod +x /usr/local/mx-ui/bin/xray-linux-${arch}
        rm -rf /tmp/xray
        rm -f /tmp/xray.zip
    fi
    
    # 清理临时目录
    cd /usr/local
    rm -rf ${TEMP_DIR}
    
    echo -e "${green}mx-ui编译完成${plain}"
    ls -la /usr/local/mx-ui/
}

# 配置服务脚本
setup_service() {
    echo -e "${green}配置服务...${plain}"
    
    # 创建服务文件
    cat > /etc/systemd/system/mx-ui.service << EOF
[Unit]
Description=mx-ui Service
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/mx-ui/
ExecStart=/usr/local/mx-ui/mx-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # 创建管理脚本
    cat > /usr/local/mx-ui/mx-ui-script << EOF
#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 检查是否为root用户
[[ \$EUID -ne 0 ]] && echo -e "\${red}错误: \${plain}必须使用root用户运行此脚本!\n" && exit 1

# 系统架构检测
arch=\$(arch)
if [[ \$arch == "x86_64" || \$arch == "x64" || \$arch == "amd64" ]]; then
    arch="amd64"
elif [[ \$arch == "aarch64" || \$arch == "arm64" ]]; then
    arch="arm64"
elif [[ \$arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "\${red}未检测到系统架构，使用默认架构: \${arch}\${plain}"
fi

# 显示菜单
show_menu() {
    echo -e "
  \${green}mx-ui 管理脚本\${plain}
  \${green}1.\${plain}  启动 mx-ui
  \${green}2.\${plain}  停止 mx-ui
  \${green}3.\${plain}  重启 mx-ui
  \${green}4.\${plain}  查看 mx-ui 状态
  \${green}5.\${plain}  查看 mx-ui 日志
  \${green}6.\${plain}  设置 mx-ui 开机自启
  \${green}7.\${plain}  取消 mx-ui 开机自启
  \${green}8.\${plain}  升级 mx-ui
  \${green}9.\${plain}  卸载 mx-ui
  \${green}10.\${plain} 查看/修改面板设置
  \${green}0.\${plain}  退出脚本
  "
    echo && read -p "请输入选择 [0-10]: " num

    case "\${num}" in
        0) exit 0 ;;
        1) start_mx_ui ;;
        2) stop_mx_ui ;;
        3) restart_mx_ui ;;
        4) check_mx_ui_status ;;
        5) view_mx_ui_log ;;
        6) enable_mx_ui ;;
        7) disable_mx_ui ;;
        8) update_mx_ui ;;
        9) uninstall_mx_ui ;;
        10) modify_mx_ui_settings ;;
        *) echo -e "\${red}请输入正确的数字 [0-10]\${plain}" ;;
    esac
}

# 启动mx-ui
start_mx_ui() {
    systemctl start mx-ui
    sleep 2
    check_mx_ui_status
}

# 停止mx-ui
stop_mx_ui() {
    systemctl stop mx-ui
    sleep 2
    check_mx_ui_status
}

# 重启mx-ui
restart_mx_ui() {
    systemctl restart mx-ui
    sleep 2
    check_mx_ui_status
}

# 查看mx-ui状态
check_mx_ui_status() {
    systemctl status mx-ui -l
    if [[ \$? == 0 ]]; then
        echo -e "mx-ui端口: \$(get_mx_ui_port)"
    fi
}

# 查看mx-ui日志
view_mx_ui_log() {
    journalctl -u mx-ui -n 50 --no-pager
}

# 设置开机自启
enable_mx_ui() {
    systemctl enable mx-ui
    if [[ \$? == 0 ]]; then
        echo -e "\${green}设置mx-ui开机自启成功\${plain}"
    else
        echo -e "\${red}设置mx-ui开机自启失败\${plain}"
    fi
}

# 取消开机自启
disable_mx_ui() {
    systemctl disable mx-ui
    if [[ \$? == 0 ]]; then
        echo -e "\${green}取消mx-ui开机自启成功\${plain}"
    else
        echo -e "\${red}取消mx-ui开机自启失败\${plain}"
    fi
}

# 获取mx-ui端口
get_mx_ui_port() {
    /usr/local/mx-ui/mx-ui setting -show | grep "端口:" | awk '{print \$2}'
}

# 修改mx-ui设置
modify_mx_ui_settings() {
    echo -e "\${yellow}当前mx-ui设置:\${plain}"
    /usr/local/mx-ui/mx-ui setting -show
    
    echo ""
    echo -e "\${yellow}修改设置:\${plain}"
    echo -e "\${green}1.\${plain} 修改用户名和密码"
    echo -e "\${green}2.\${plain} 修改面板端口"
    echo -e "\${green}0.\${plain} 返回主菜单"
    
    read -p "请选择 [0-2]: " setting_num
    case \$setting_num in
        1)
            read -p "请输入新用户名: " new_username
            read -p "请输入新密码: " new_password
            /usr/local/mx-ui/mx-ui setting -username \$new_username -password \$new_password
            echo -e "\${green}用户名和密码已更新\${plain}"
            ;;
        2)
            read -p "请输入新端口: " new_port
            /usr/local/mx-ui/mx-ui setting -port \$new_port
            echo -e "\${green}端口已更新\${plain}"
            ;;
        0) show_menu ;;
        *) echo -e "\${red}请输入正确的数字 [0-2]\${plain}" ;;
    esac
}

# 升级mx-ui
update_mx_ui() {
    bash <(curl -Ls https://raw.githubusercontent.com/MissChina/mx-ui/main/install.sh)
}

# 卸载mx-ui
uninstall_mx_ui() {
    echo -e "\${yellow}确定要卸载mx-ui吗? (y/n)\${plain}"
    read -p "": yn
    if [[ \$yn =~ ^[Yy]\$ ]]; then
        systemctl stop mx-ui
        systemctl disable mx-ui
        rm -rf /usr/local/mx-ui
        rm -f /etc/systemd/system/mx-ui.service
        rm -f /usr/bin/mx-ui
        systemctl daemon-reload
        echo -e "\${green}卸载成功\${plain}"
    fi
}

if [[ \$# > 0 ]]; then
    case \$1 in
        start) start_mx_ui ;;
        stop) stop_mx_ui ;;
        restart) restart_mx_ui ;;
        status) check_mx_ui_status ;;
        log) view_mx_ui_log ;;
        enable) enable_mx_ui ;;
        disable) disable_mx_ui ;;
        update) update_mx_ui ;;
        install) bash <(curl -Ls https://raw.githubusercontent.com/MissChina/mx-ui/main/install.sh) ;;
        uninstall) uninstall_mx_ui ;;
        setting)
            if [[ \$# == 2 && \$2 == "show" ]]; then
                /usr/local/mx-ui/mx-ui setting -show
            else
                modify_mx_ui_settings
            fi
            ;;
        *) show_menu ;;
    esac
else
    show_menu
fi
EOF

    chmod +x /usr/local/mx-ui/mx-ui-script
    ln -sf /usr/local/mx-ui/mx-ui-script /usr/bin/mx-ui
    
    echo -e "${green}服务配置完成${plain}"
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
    if [[ -f "/usr/local/mx-ui/mx-ui" && -x "/usr/local/mx-ui/mx-ui" ]]; then
        /usr/local/mx-ui/mx-ui setting -username ${config_username} -password ${config_password}
        /usr/local/mx-ui/mx-ui setting -port ${config_port}
        
        # 显示设置信息
        echo -e "\n${green}mx-ui 面板配置信息：${plain}"
        echo -e "用户名: ${config_username}"
        echo -e "密码: ${config_password}"
        echo -e "面板访问端口: ${config_port}"
    else
        echo -e "${red}mx-ui 程序不存在或不可执行，配置失败${plain}"
        # 创建配置文件目录
        mkdir -p /usr/local/mx-ui/config
        # 保存配置到临时文件，等待下次启动时使用
        echo "{\"username\":\"${config_username}\",\"password\":\"${config_password}\",\"port\":${config_port}}" > /usr/local/mx-ui/config/settings.json
        
        echo -e "\n${yellow}mx-ui 面板临时配置信息（将在程序启动时应用）：${plain}"
        echo -e "用户名: ${config_username}"
        echo -e "密码: ${config_password}"
        echo -e "面板访问端口: ${config_port}"
    fi
}

# 安装mx-ui
install_mx_ui() {
    systemctl stop mx-ui 2>/dev/null
    
    mkdir -p /usr/local/mx-ui/
    
    local package_file=""
    
    if [ $# -gt 0 ]; then
        last_version=$1
        url="https://github.com/MissChina/mx-ui/releases/download/${last_version}/mx-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 mx-ui $1"
        package_file="/usr/local/mx-ui-linux-${arch}-${last_version}.tar.gz"
    else
        echo -e "开始安装 mx-ui 最新版本"
        url="https://github.com/MissChina/mx-ui/releases/download/v1.0.0/mx-ui-linux-${arch}.tar.gz"
        last_version="v1.0.0"
        package_file="/usr/local/mx-ui-linux-${arch}.tar.gz"
    fi

    echo -e "从 ${url} 下载 mx-ui"
    wget -N --no-check-certificate -O ${package_file} ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 mx-ui 失败，尝试使用备用下载方式${plain}"
        curl -L -o ${package_file} ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 mx-ui 失败，跳过解压步骤${plain}"
            package_file=""
        fi
    fi

    # 尝试解压文件
    if [[ -n "${package_file}" && -f "${package_file}" ]]; then
        echo -e "解压文件 ${package_file}"
        tar -xzf ${package_file} -C /usr/local/
        if [[ $? -ne 0 ]]; then
            echo -e "${red}解压文件失败，可能是文件损坏${plain}"
            rm -f ${package_file}
            package_file=""
        else
            rm -f ${package_file}
        fi
    fi
    
    cd /usr/local/mx-ui || exit 1
    
    # 检查mx-ui可执行文件是否存在
    if [[ ! -f "mx-ui" || ! -x "mx-ui" ]]; then
        echo -e "${yellow}未找到可执行文件或文件不可执行，尝试编译${plain}"
        # 安装Go环境
        install_go
        
        # 编译mx-ui
        compile_mx_ui
    fi
    
    # 再次检查mx-ui可执行文件是否存在
    if [[ ! -f "mx-ui" || ! -x "mx-ui" ]]; then
        echo -e "${red}mx-ui 编译失败或文件不存在，安装失败${plain}"
        echo -e "${yellow}请手动安装或联系作者解决${plain}"
        exit 1
    fi
    
    # 确保二进制文件可执行
    chmod +x mx-ui 2>/dev/null
    chmod +x bin/xray-linux-${arch} 2>/dev/null
    
    # 设置服务
    setup_service
    
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