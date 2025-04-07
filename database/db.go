package database

import (
	"mx-ui/config"
	"mx-ui/logger"
	"os"
	"path/filepath"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
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
	gormLogger := logger.New(
		&DBWriter{},
		logger.Config{
			LogLevel: logger.Warn, // 日志级别
			Colorful: false,       // 禁用彩色日志
		},
	)

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

func (w *DBWriter) Printf(format string, args ...interface{}) {
	logger.Infof(format, args...)
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
	Key   string `gorm:"unique"`
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
	Date       string  `gorm:"uniqueIndex:idx_server_stat_date"`
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
	return `{
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
	}`
} 