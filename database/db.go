package database

import (
	"os"
	"path/filepath"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var db *gorm.DB

// GetDB 获取数据库连接
func GetDB() *gorm.DB {
	return db
}

// InitDB 初始化数据库
func InitDB(dbPath string) error {
	// 确保数据库所在目录存在
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, os.ModePerm); err != nil {
		return err
	}

	// 打开数据库
	var err error
	db, err = gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
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
	sqlDB.SetMaxIdleConns(1)
	sqlDB.SetConnMaxLifetime(0)

	// 自动迁移数据库表结构
	err = initModels()
	if err != nil {
		return err
	}

	// 初始化默认数据
	initUser()

	return nil
}

// initModels 初始化数据库表结构
func initModels() error {
	return db.AutoMigrate(
		&User{},
		&Setting{},
		&InboundConfig{},
		&ClientConfig{},
		&ServerStat{},
	)
}

// initUser 初始化默认用户
func initUser() {
	var count int64
	db.Model(&User{}).Count(&count)
	if count > 0 {
		return
	}

	// 创建默认管理员账户
	user := User{
		Username: "admin",
		Password: "admin",
	}
	db.Create(&user)
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

// IsNotFound 检查是否是记录未找到错误
func IsNotFound(err error) bool {
	return err == gorm.ErrRecordNotFound
}

// AutoMigrate 自动迁移数据库表结构
func AutoMigrate() error {
	// 在此处添加所有需要迁移的模型
	return db.AutoMigrate(
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

// InitUser 初始化默认用户
func InitUser() {
	var count int64
	db.Model(&User{}).Count(&count)
	if count > 0 {
		return
	}

	// 创建默认管理员账户
	user := User{
		Username: "admin",
		Password: "admin",
	}
	db.Create(&user)
}

// InitSetting 初始化默认设置
func InitSetting() {
	settings := []Setting{
		{Key: "webPort", Value: "54321"},
		{Key: "webBasePath", Value: "/"},
		{Key: "xrayConfigTemplate", Value: GetDefaultXrayConfigTemplate()},
	}

	for _, setting := range settings {
		db.FirstOrCreate(&Setting{}, Setting{Key: setting.Key}).Update("Value", setting.Value)
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