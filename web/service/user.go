package service

import (
	"errors"
	"mx-ui/database"
)

// UserService 用户相关服务
type UserService struct{}

// GetFirstUser 获取第一个（管理员）用户
func (s *UserService) GetFirstUser() (*database.User, error) {
	user := &database.User{}
	err := database.DB.First(user).Error
	if err != nil {
		return nil, err
	}
	return user, nil
}

// CheckLogin 检查用户登录
func (s *UserService) CheckLogin(username string, password string) (*database.User, error) {
	user := &database.User{}
	err := database.DB.Where("username = ? AND password = ?", username, password).First(user).Error
	if err != nil {
		return nil, errors.New("用户名或密码错误")
	}
	return user, nil
}

// UpdateFirstUser 更新第一个用户的信息
func (s *UserService) UpdateFirstUser(username string, password string) error {
	user, err := s.GetFirstUser()
	if err != nil {
		return err
	}

	if username != "" {
		user.Username = username
	}
	if password != "" {
		user.Password = password
	}

	return database.DB.Save(user).Error
}

// GetUserCount 获取用户数量
func (s *UserService) GetUserCount() (int64, error) {
	var count int64
	err := database.DB.Model(&database.User{}).Count(&count).Error
	if err != nil {
		return 0, err
	}
	return count, nil
}

// HasUser 判断是否有用户
func (s *UserService) HasUser() (bool, error) {
	count, err := s.GetUserCount()
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// IsFirstRun 判断是否为首次运行
func (s *UserService) IsFirstRun() (bool, error) {
	has, err := s.HasUser()
	if err != nil {
		return false, err
	}
	return !has, nil
} 