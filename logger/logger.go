package logger

import (
	"io"
	"mx-ui/config"
	"os"
	"time"

	"github.com/op/go-logging"
)

var logger *logging.Logger

func InitLogger(level logging.Level) {
	// 创建日志对象
	logger = logging.MustGetLogger(config.GetName())

	// 创建日志格式
	consoleFormat := logging.MustStringFormatter(
		`%{time:2006-01-02 15:04:05.000} %{level} %{message}`,
	)
	fileFormat := logging.MustStringFormatter(
		`%{time:2006-01-02 15:04:05.000} %{level} %{message}`,
	)

	// 控制台输出
	consoleBackend := logging.NewLogBackend(os.Stderr, "", 0)
	consoleFormatter := logging.NewBackendFormatter(consoleBackend, consoleFormat)
	consoleBackendLeveled := logging.AddModuleLevel(consoleFormatter)
	consoleBackendLeveled.SetLevel(level, "")

	// 文件输出
	var backends []logging.Backend
	backends = append(backends, consoleBackendLeveled)

	// 创建日志文件
	logFilePath := config.LogFilePath
	if logFilePath != "" {
		// 确保日志目录存在
		logDir := config.DataDirPath
		err := os.MkdirAll(logDir, 0755)
		if err != nil {
			logger.Error("创建日志目录失败:", err)
			return
		}

		// 打开或创建日志文件
		logFile, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			logger.Error("打开日志文件失败:", err)
			return
		}

		// 创建文件后端
		fileBackend := logging.NewLogBackend(logFile, "", 0)
		fileFormatter := logging.NewBackendFormatter(fileBackend, fileFormat)
		fileBackendLeveled := logging.AddModuleLevel(fileFormatter)
		fileBackendLeveled.SetLevel(level, "")
		backends = append(backends, fileBackendLeveled)

		// 每日轮转日志文件
		go rotateLogDaily(logFilePath)
	}

	// 设置后端
	logging.SetBackend(backends...)
}

// 轮转日志文件
func rotateLogDaily(logPath string) {
	for {
		// 计算下一次轮转时间（第二天的零点）
		now := time.Now()
		next := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, now.Location())
		duration := next.Sub(now)

		// 等待到轮转时间
		time.Sleep(duration)

		// 重命名当前日志文件
		backupPath := logPath + "." + now.Format("2006-01-02")
		err := os.Rename(logPath, backupPath)
		if err != nil {
			Error("轮转日志文件失败:", err)
			continue
		}

		// 重新初始化日志器
		level := logging.GetLevel("")
		InitLogger(level)
	}
}

// Debug 记录调试级别日志
func Debug(args ...interface{}) {
	if logger != nil {
		logger.Debug(args...)
	}
}

// Debugf 记录调试级别日志（格式化）
func Debugf(format string, args ...interface{}) {
	if logger != nil {
		logger.Debugf(format, args...)
	}
}

// Info 记录信息级别日志
func Info(args ...interface{}) {
	if logger != nil {
		logger.Info(args...)
	}
}

// Infof 记录信息级别日志（格式化）
func Infof(format string, args ...interface{}) {
	if logger != nil {
		logger.Infof(format, args...)
	}
}

// Warning 记录警告级别日志
func Warning(args ...interface{}) {
	if logger != nil {
		logger.Warning(args...)
	}
}

// Warningf 记录警告级别日志（格式化）
func Warningf(format string, args ...interface{}) {
	if logger != nil {
		logger.Warningf(format, args...)
	}
}

// Error 记录错误级别日志
func Error(args ...interface{}) {
	if logger != nil {
		logger.Error(args...)
	}
}

// Errorf 记录错误级别日志（格式化）
func Errorf(format string, args ...interface{}) {
	if logger != nil {
		logger.Errorf(format, args...)
	}
}

// Fatal 记录致命级别日志
func Fatal(args ...interface{}) {
	if logger != nil {
		logger.Fatal(args...)
	}
}

// Fatalf 记录致命级别日志（格式化）
func Fatalf(format string, args ...interface{}) {
	if logger != nil {
		logger.Fatalf(format, args...)
	}
}

// GetWriter 获取日志写入器（用于其他需要io.Writer的场合）
func GetWriter() io.Writer {
	return &logWriter{}
}

// logWriter 实现io.Writer接口的写入器
type logWriter struct{}

func (w *logWriter) Write(p []byte) (n int, err error) {
	Info(string(p))
	return len(p), nil
} 