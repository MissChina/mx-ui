package service

import (
	"errors"
	"mx-ui/config"
	"mx-ui/database"
	"mx-ui/logger"
	"strconv"
)

// SettingService 系统设置相关服务
type SettingService struct{}

// GetPort 获取Web端口
func (s *SettingService) GetPort() (int, error) {
	port := ""
	err := s.getSetting("webPort", &port)
	if err != nil {
		return 0, err
	}
	portNum, err := strconv.Atoi(port)
	if err != nil {
		return 0, err
	}
	return portNum, nil
}

// SetPort 设置Web端口
func (s *SettingService) SetPort(port int) error {
	if port <= 0 || port > 65535 {
		return errors.New("端口范围必须在1-65535之间")
	}
	return s.saveSetting("webPort", strconv.Itoa(port))
}

// GetCertFile 获取证书文件
func (s *SettingService) GetCertFile() (string, error) {
	certFile := ""
	err := s.getSetting("certFile", &certFile)
	if err != nil {
		return config.GetCertFile(), err
	}
	if certFile == "" {
		return config.GetCertFile(), nil
	}
	return certFile, nil
}

// SetCertFile 设置证书文件
func (s *SettingService) SetCertFile(certFile string) error {
	return s.saveSetting("certFile", certFile)
}

// GetKeyFile 获取密钥文件
func (s *SettingService) GetKeyFile() (string, error) {
	keyFile := ""
	err := s.getSetting("keyFile", &keyFile)
	if err != nil {
		return config.GetKeyFile(), err
	}
	if keyFile == "" {
		return config.GetKeyFile(), nil
	}
	return keyFile, nil
}

// SetKeyFile 设置密钥文件
func (s *SettingService) SetKeyFile(keyFile string) error {
	return s.saveSetting("keyFile", keyFile)
}

// GetBasePath 获取网页基础路径
func (s *SettingService) GetBasePath() (string, error) {
	basePath := ""
	err := s.getSetting("webBasePath", &basePath)
	if err != nil {
		return "", err
	}
	if basePath == "" {
		return "/", nil
	}
	// 确保以/开头
	if basePath[0] != '/' {
		basePath = "/" + basePath
	}
	// 确保以/结尾
	if basePath[len(basePath)-1] != '/' {
		basePath = basePath + "/"
	}
	return basePath, nil
}

// SetBasePath 设置网页基础路径
func (s *SettingService) SetBasePath(basePath string) error {
	if basePath == "" {
		basePath = "/"
	}
	// 确保以/开头
	if basePath[0] != '/' {
		basePath = "/" + basePath
	}
	// 确保以/结尾
	if len(basePath) > 1 && basePath[len(basePath)-1] != '/' {
		basePath = basePath + "/"
	}
	return s.saveSetting("webBasePath", basePath)
}

// GetXrayConfigTemplate 获取Xray配置模板
func (s *SettingService) GetXrayConfigTemplate() (string, error) {
	template := ""
	err := s.getSetting("xrayConfigTemplate", &template)
	if err != nil {
		return "", err
	}
	if template == "" {
		return database.GetDefaultXrayConfigTemplate(), nil
	}
	return template, nil
}

// SetXrayConfigTemplate 设置Xray配置模板
func (s *SettingService) SetXrayConfigTemplate(template string) error {
	return s.saveSetting("xrayConfigTemplate", template)
}

// ResetSettings 重置所有设置
func (s *SettingService) ResetSettings() error {
	return database.GetDB().Where("1 = 1").Delete(&database.Setting{}).Error
}

// getSetting 获取设置值
func (s *SettingService) getSetting(key string, value *string) error {
	setting := &database.Setting{}
	err := database.GetDB().Where("key = ?", key).First(setting).Error
	if err != nil {
		return err
	}
	*value = setting.Value
	return nil
}

// saveSetting 保存设置值
func (s *SettingService) saveSetting(key string, value string) error {
	setting := &database.Setting{}
	err := database.GetDB().Where("key = ?", key).First(setting).Error
	if err != nil {
		logger.Warning("设置", key, "不存在，将创建它")
		setting = &database.Setting{
			Key:   key,
			Value: value,
		}
		return database.GetDB().Create(setting).Error
	}
	setting.Value = value
	return database.GetDB().Save(setting).Error
} 