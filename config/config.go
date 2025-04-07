package config

import (
	"bytes"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"
)

const (
	Name           = "mx-ui"
	Version        = "1.0.0"
	APIPrefix      = "/api"
	BasePath       = "/app/"
	DataDirName    = "mx-ui"
	TempPath       = "temp"
	DBName         = "mx-ui.db"
	CertFileName   = "mx-ui.cert"
	KeyFileName    = "mx-ui.key"
	DefaultWebPort = 54321
	Debug          = "debug"
	Info           = "info"
	Warn           = "warn"
	Error          = "error"
	Notice         = "notice"
)

var (
	ConfigDirPath string
	DataDirPath   string
	LogFilePath   string
)

var LogLevel = Info

func GetVersion() string {
	return Version
}

func GetName() string {
	return Name
}

func GetLogLevel() string {
	return LogLevel
}

func GetDBPath() string {
	return path.Join(DataDirPath, DBName)
}

func GetTempPath() string {
	return path.Join(DataDirPath, TempPath)
}

func GetCertFile() string {
	return path.Join(DataDirPath, CertFileName)
}

func GetKeyFile() string {
	return path.Join(DataDirPath, KeyFileName)
}

func GetDefaultWebPort() int {
	return DefaultWebPort
}

// 初始化函数
func init() {
	initDataDir()
}

// 初始化数据目录
func initDataDir() {
	var err error
	// 获取用户根目录
	home, err := os.UserHomeDir()
	if err != nil {
		// 回退到程序所在目录
		execPath, err := os.Executable()
		if err != nil {
			// 最后回退到当前目录
			DataDirPath = DataDirName
		} else {
			DataDirPath = path.Join(filepath.Dir(execPath), DataDirName)
		}
	} else {
		// 在用户主目录创建配置目录
		if runtime.GOOS == "windows" {
			DataDirPath = path.Join(home, DataDirName)
		} else {
			DataDirPath = path.Join(home, ".config", DataDirName)
		}
	}

	// 创建数据目录
	err = os.MkdirAll(DataDirPath, os.ModePerm)
	if err != nil {
		fmt.Println("无法创建数据目录:", err)
	}

	// 设置日志文件路径
	LogFilePath = path.Join(DataDirPath, "mx-ui.log")

	// 创建临时目录
	tempPath := GetTempPath()
	err = os.MkdirAll(tempPath, os.ModePerm)
	if err != nil {
		fmt.Println("无法创建临时目录:", err)
	}
}

// NormalizeFilePath 标准化文件路径，处理不同操作系统的文件路径
func NormalizeFilePath(filePath string) string {
	if runtime.GOOS == "windows" {
		// 将 / 转换为 \
		filePath = strings.ReplaceAll(filePath, "/", "\\")
	} else {
		// 将 \ 转换为 /
		filePath = strings.ReplaceAll(filePath, "\\", "/")
	}
	return filePath
}

// CompressPath 压缩路径，防止路径太长
func CompressPath(filePath string) string {
	if filePath == "" {
		return ""
	}

	var buffer bytes.Buffer
	parts := strings.Split(filePath, string(os.PathSeparator))
	
	for i, part := range parts {
		if i == len(parts)-1 {
			// 最后一部分保留完整
			buffer.WriteString(part)
		} else if i > 0 && i < len(parts)-2 {
			// 中间部分缩写为首字母
			if len(part) > 0 {
				buffer.WriteByte(part[0])
			}
			buffer.WriteString(string(os.PathSeparator))
		} else {
			// 第一部分和倒数第二部分保留完整
			buffer.WriteString(part)
			buffer.WriteString(string(os.PathSeparator))
		}
	}
	
	return buffer.String()
} 