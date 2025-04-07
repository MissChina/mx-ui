#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

# 检查是否为Root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误：必须使用root用户运行此脚本！${PLAIN}"
        exit 1
    fi
}

# 检查系统架构
check_arch() {
    arch=$(uname -m)
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        ARCH="amd64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        ARCH="arm64"
    else
        echo -e "${RED}不支持的系统架构: ${arch}${PLAIN}"
        exit 1
    fi
    echo -e "系统架构: ${ARCH}"
}

# 检查系统类型
check_os() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
    else
        echo -e "${RED}未检测到系统版本，请联系脚本作者！${PLAIN}"
        exit 1
    fi
    echo -e "系统版本: ${OS}"
}

# 安装依赖
install_dependencies() {
    echo -e "${GREEN}安装依赖...${PLAIN}"
    if [[ ${OS} == "centos" ]]; then
        yum update -y
        yum install wget curl tar git -y
    else
        apt update -y
        apt install wget curl tar git -y
    fi
}

# 检查并安装Go环境
install_go() {
    if command -v go >/dev/null 2>&1; then
        GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        echo -e "${GREEN}已安装Go版本: ${GO_VERSION}${PLAIN}"
        
        # 版本比较，确保版本 >= 1.19
        MAJOR=$(echo $GO_VERSION | cut -d. -f1)
        MINOR=$(echo $GO_VERSION | cut -d. -f2)
        
        if [ "$MAJOR" -gt 1 ] || ([ "$MAJOR" -eq 1 ] && [ "$MINOR" -ge 19 ]); then
            echo -e "${GREEN}Go版本满足要求${PLAIN}"
            return 0
        else
            echo -e "${YELLOW}已安装的Go版本过低，需要重新安装${PLAIN}"
        fi
    fi

    echo -e "${GREEN}正在安装Go环境...${PLAIN}"
    GO_VERSION="1.21.0"
    wget -q -O /tmp/go.tar.gz https://dl.google.com/go/go${GO_VERSION}.linux-${ARCH}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载Go失败，请检查网络连接${PLAIN}"
        exit 1
    fi
    
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    
    # 设置Go环境变量
    echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
    chmod +x /etc/profile.d/go.sh
    source /etc/profile.d/go.sh
    
    echo -e "${GREEN}Go安装完成${PLAIN}"
    go version
}

# 下载预编译的mx-ui二进制文件
download_mxui() {
    echo -e "${GREEN}开始下载预编译的mx-ui版本${PLAIN}"
    MX_UI_VERSION="v1.0.1"
    MX_UI_FILE="mx-ui-linux-${ARCH}.tar.gz"
    
    echo -e "从 https://github.com/MissChina/mx-ui/releases/download/${MX_UI_VERSION}/${MX_UI_FILE} 下载 mx-ui"
    wget -O /usr/local/${MX_UI_FILE} https://github.com/MissChina/mx-ui/releases/download/${MX_UI_VERSION}/${MX_UI_FILE}
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}下载预编译版本失败，将尝试从源码编译${PLAIN}"
        return 1
    fi
    
    echo -e "${GREEN}下载成功，解压文件 /usr/local/${MX_UI_FILE}${PLAIN}"
    mkdir -p /usr/local/mx-ui
    tar -xzf /usr/local/${MX_UI_FILE} -C /usr/local/mx-ui
    
    if [ -f /usr/local/mx-ui/mx-ui ]; then
        chmod +x /usr/local/mx-ui/mx-ui
        echo -e "${GREEN}mx-ui 预编译版本安装成功${PLAIN}"
        return 0
    else
        echo -e "${YELLOW}未找到可执行文件或文件不可执行，尝试编译${PLAIN}"
        return 1
    fi
}

# 编译mx-ui
compile_mxui() {
    echo -e "${GREEN}正在编译mx-ui...${PLAIN}"
    TMP_DIR=$(mktemp -d)
    echo -e "临时目录: ${TMP_DIR}"
    
    echo -e "克隆源码..."
    git clone https://github.com/MissChina/mx-ui.git ${TMP_DIR}
    cd ${TMP_DIR}
    
    echo -e "修复数据库代码..."
    # 修复database/db.go文件
    cat > database/db.go << EOF
package database

import (
	"context"
	"os"
	"path/filepath"
	"time"

	"mx-ui/logger"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB

// InitDB 初始化数据库
func InitDB(dbPath string) error {
	// 确保数据库所在目录存在
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, os.ModePerm); err != nil {
		return err
	}

	// 配置GORM日志
	gormLogger := &DBWriter{}

	// 打开数据库
	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		return err
	}

	// 获取连接池配置
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}

	// 设置连接池参数
	sqlDB.SetMaxOpenConns(1) // SQLite只支持单连接

	DB = db

	// 自动迁移数据库表结构
	err = AutoMigrate()
	if err != nil {
		return err
	}

	// 初始化默认数据
	InitData()

	return nil
}

// DBWriter 实现GORM日志输出到自定义的日志系统
type DBWriter struct{}

// Printf 实现日志格式化输出
func (w *DBWriter) Printf(format string, args ...interface{}) {
	logger.Infof(format, args...)
}

// LogMode 实现gorm.Logger接口
func (w *DBWriter) LogMode(level gorm.LogLevel) gorm.Logger {
	return w
}

// Info 实现gorm.Logger接口
func (w *DBWriter) Info(ctx context.Context, msg string, data ...interface{}) {
	logger.Infof(msg, data...)
}

// Warn 实现gorm.Logger接口
func (w *DBWriter) Warn(ctx context.Context, msg string, data ...interface{}) {
	logger.Warningf(msg, data...)
}

// Error 实现gorm.Logger接口
func (w *DBWriter) Error(ctx context.Context, msg string, data ...interface{}) {
	logger.Errorf(msg, data...)
}

// Trace 实现gorm.Logger接口
func (w *DBWriter) Trace(ctx context.Context, begin time.Time, fc func() (string, int64), err error) {
	elapsed := time.Since(begin)
	sql, rows := fc()
	if err != nil {
		logger.Errorf("%s [%v], rows: %v, %s", sql, elapsed, rows, err.Error())
		return
	}
	logger.Debugf("%s [%v], rows: %v", sql, elapsed, rows)
}

// AutoMigrate 自动迁移数据库表结构
func AutoMigrate() error {
	// 在此处添加所有需要迁移的模型
	return DB.AutoMigrate(
		&User{},
		&Setting{},
		&InboundConfig{},
		&ClientConfig{},
		&ServerStat{},
	)
}

// InitData 初始化默认数据
func InitData() {
	InitUser()
	InitSetting()
}

// User 用户模型
type User struct {
	gorm.Model
	Username string
	Password string
}

// Setting 设置模型
type Setting struct {
	gorm.Model
	Key   string \`gorm:"unique"\`
	Value string
}

// InboundConfig 入站配置模型
type InboundConfig struct {
	gorm.Model
	Protocol       string
	Tag            string
	Port           int
	Enable         bool
	Settings       string
	StreamSettings string
	Remark         string
}

// ClientConfig 客户端配置模型
type ClientConfig struct {
	gorm.Model
	InboundID  uint
	Email      string
	UUID       string
	Enable     bool
	ExpiryTime int64
	Limit      int64
	Used       int64
	Remark     string
}

// ServerStat 服务器统计数据模型
type ServerStat struct {
	gorm.Model
	Date       string  \`gorm:"uniqueIndex:idx_server_stat_date"\`
	CPU        float64
	Mem        float64
	NetworkIn  int64
	NetworkOut int64
}

// InitUser 初始化默认用户
func InitUser() {
	var count int64
	DB.Model(&User{}).Count(&count)
	if count > 0 {
		return
	}

	// 创建默认管理员账户
	user := User{
		Username: "admin",
		Password: "admin",
	}
	DB.Create(&user)
}

// InitSetting 初始化默认设置
func InitSetting() {
	settings := []Setting{
		{Key: "webPort", Value: "54321"},
		{Key: "webBasePath", Value: "/"},
		{Key: "xrayConfigTemplate", Value: GetDefaultXrayConfigTemplate()},
	}

	for _, setting := range settings {
		DB.FirstOrCreate(&Setting{}, Setting{Key: setting.Key}).Update("Value", setting.Value)
	}
}

// GetDefaultXrayConfigTemplate 获取默认的Xray配置模板
func GetDefaultXrayConfigTemplate() string {
	return \`{
		"log": {
			"loglevel": "warning",
			"access": "./access.log",
			"error": "./error.log"
		},
		"inbounds": [],
		"outbounds": [
			{
				"protocol": "freedom"
			}
		],
		"routing": {
			"rules": [
				{
					"type": "field",
					"ip": [
						"geoip:private"
					],
					"outboundTag": "blocked"
				}
			]
		}
	}\`
}
EOF
    
    echo -e "下载依赖..."
    GOPROXY=https://goproxy.io,direct
    go mod tidy
    
    echo -e "开始编译..."
    go build -o mx-ui main.go
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}编译失败${PLAIN}"
        return 1
    fi
    
    echo -e "${GREEN}编译成功${PLAIN}"
    
    # 安装到系统
    install_mxui
    return $?
}

# 安装mx-ui
install_mxui() {
    echo -e "${GREEN}安装mx-ui到系统${PLAIN}"
    
    # 创建安装目录
    mkdir -p /usr/local/mx-ui/bin
    mkdir -p /usr/local/mx-ui/web
    
    # 复制文件
    if [ -f "${TMP_DIR}/mx-ui" ]; then
        cp ${TMP_DIR}/mx-ui /usr/local/mx-ui/bin/
    elif [ -f "./mx-ui" ]; then
        cp ./mx-ui /usr/local/mx-ui/bin/
    else
        echo -e "${RED}未找到mx-ui可执行文件${PLAIN}"
        return 1
    fi
    
    chmod +x /usr/local/mx-ui/bin/mx-ui
    
    # 复制Web页面和其他资源
    if [ -d "${TMP_DIR}/web" ]; then
        cp -r ${TMP_DIR}/web /usr/local/mx-ui/
    elif [ -d "./web" ]; then
        cp -r ./web /usr/local/mx-ui/
    else
        echo -e "${RED}未找到web目录${PLAIN}"
        return 1
    fi
    
    # 创建数据目录
    mkdir -p /etc/mx-ui
    mkdir -p /var/log/mx-ui
    
    # 创建服务文件
    cat > /etc/systemd/system/mx-ui.service << EOF
[Unit]
Description=MX-UI Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/mx-ui/bin
ExecStart=/usr/local/mx-ui/bin/mx-ui
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载服务
    systemctl daemon-reload
    systemctl enable mx-ui
    systemctl start mx-ui
    
    # 等待服务启动
    sleep 2
    
    # 检查服务状态
    if systemctl is-active --quiet mx-ui; then
        echo -e "${GREEN}mx-ui 服务启动成功${PLAIN}"
    else
        echo -e "${YELLOW}mx-ui 服务启动失败，请检查日志：journalctl -u mx-ui${PLAIN}"
    fi
    
    echo -e "${GREEN}mx-ui 安装成功！${PLAIN}"
    echo -e "访问地址: ${GREEN}http://$(curl -s ifconfig.me):54321${PLAIN}"
    echo -e "默认用户名: ${GREEN}admin${PLAIN}"
    echo -e "默认密码: ${GREEN}admin${PLAIN}"
    
    return 0
}

# 卸载mx-ui
uninstall_mxui() {
    echo -e "${YELLOW}即将卸载mx-ui...${PLAIN}"
    
    # 停止并禁用服务
    systemctl stop mx-ui
    systemctl disable mx-ui
    
    # 删除服务文件
    rm -f /etc/systemd/system/mx-ui.service
    systemctl daemon-reload
    
    # 询问是否保留数据
    read -p "是否保留配置数据？[y/n]: " keep_data
    if [[ "${keep_data,,}" == "n" ]]; then
        rm -rf /etc/mx-ui
        rm -rf /var/log/mx-ui
        echo -e "${GREEN}配置数据已删除${PLAIN}"
    else
        echo -e "${GREEN}配置数据已保留${PLAIN}"
    fi
    
    # 删除安装文件
    rm -rf /usr/local/mx-ui
    
    echo -e "${GREEN}mx-ui 卸载完成${PLAIN}"
}

# 更新mx-ui
update_mxui() {
    echo -e "${GREEN}开始更新mx-ui...${PLAIN}"
    
    # 备份配置
    if [ -d "/etc/mx-ui" ]; then
        cp -r /etc/mx-ui /etc/mx-ui.bak
        echo -e "${GREEN}配置已备份到 /etc/mx-ui.bak${PLAIN}"
    fi
    
    # 停止服务
    systemctl stop mx-ui
    
    # 下载新版本或编译
    if ! download_mxui; then
        compile_mxui
    fi
    
    # 启动服务
    systemctl start mx-ui
    
    echo -e "${GREEN}mx-ui 更新完成${PLAIN}"
}

# 查看状态
show_status() {
    echo -e "${GREEN}mx-ui 状态信息:${PLAIN}"
    
    # 检查服务状态
    systemctl status mx-ui --no-pager
    
    # 获取端口信息
    if command -v netstat >/dev/null 2>&1; then
        echo -e "${GREEN}端口监听信息:${PLAIN}"
        netstat -tlnp | grep mx-ui
    elif command -v ss >/dev/null 2>&1; then
        echo -e "${GREEN}端口监听信息:${PLAIN}"
        ss -tlnp | grep mx-ui
    fi
    
    # 获取进程信息
    echo -e "${GREEN}进程信息:${PLAIN}"
    ps -ef | grep -v grep | grep mx-ui
}

# 显示帮助信息
show_help() {
    echo -e "
    ${GREEN}MX-UI 管理脚本${PLAIN}
    
    使用方法: $0 [选项]
    
    ${GREEN}选项:${PLAIN}
      ${YELLOW}install${PLAIN}    安装 MX-UI
      ${YELLOW}uninstall${PLAIN}  卸载 MX-UI
      ${YELLOW}update${PLAIN}     更新 MX-UI
      ${YELLOW}status${PLAIN}     查看 MX-UI 状态
      ${YELLOW}help${PLAIN}       显示此帮助信息
    "
}

# 主函数
main() {
    check_root
    
    # 处理命令行参数
    case "$1" in
        install)
            echo -e "${GREEN}开始安装 MX-UI...${PLAIN}"
            check_os
            check_arch
            install_dependencies
            install_go
            if ! download_mxui; then
                compile_mxui
            fi
            ;;
        uninstall)
            uninstall_mxui
            ;;
        update)
            check_os
            check_arch
            install_go
            update_mxui
            ;;
        status)
            show_status
            ;;
        help|*)
            show_help
            ;;
    esac
}

# 如果没有参数，默认显示帮助并询问安装
if [ $# -eq 0 ]; then
    show_help
    read -p "是否现在安装 MX-UI? [y/n]: " install_now
    if [[ "${install_now,,}" == "y" ]]; then
        main install
    fi
else
    main "$@"
fi 