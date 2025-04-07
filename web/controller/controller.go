package controller

import (
	"mx-ui/logger"
	"mx-ui/web/service"
	"net/http"

	"github.com/gin-contrib/sessions"
	"github.com/gin-gonic/gin"
)

// AuthMiddleware 授权中间件
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		session := sessions.Default(c)
		user := session.Get("user")
		if user == nil {
			logger.Debug("用户未登录")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "未登录或登录已过期",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

// LoginController 登录控制器
type LoginController struct{}

// Login 处理登录请求
func (a *LoginController) Login(c *gin.Context) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}

	err := c.ShouldBindJSON(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "请求参数无效",
		})
		return
	}

	if req.Username == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "用户名和密码不能为空",
		})
		return
	}

	userService := service.UserService{}
	user, err := userService.CheckLogin(req.Username, req.Password)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"success": false,
			"message": err.Error(),
		})
		return
	}

	session := sessions.Default(c)
	session.Set("user", user.ID)
	session.Set("username", user.Username)
	err = session.Save()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "保存会话信息失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "登录成功",
		"data": gin.H{
			"username": user.Username,
		},
	})
}

// Logout 处理登出请求
func (a *LoginController) Logout(c *gin.Context) {
	session := sessions.Default(c)
	session.Clear()
	err := session.Save()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "清除会话信息失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "登出成功",
	})
}

// UserController 用户控制器
type UserController struct{}

// GetUser 获取当前用户信息
func (a *UserController) GetUser(c *gin.Context) {
	session := sessions.Default(c)
	username := session.Get("username")

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"username": username,
		},
	})
}

// UpdateUser 更新用户信息
func (a *UserController) UpdateUser(c *gin.Context) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}

	err := c.ShouldBindJSON(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "请求参数无效",
		})
		return
	}

	if req.Username == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "用户名和密码不能为空",
		})
		return
	}

	userService := service.UserService{}
	err = userService.UpdateFirstUser(req.Username, req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "更新用户信息失败：" + err.Error(),
		})
		return
	}

	// 更新会话中的用户名
	session := sessions.Default(c)
	session.Set("username", req.Username)
	session.Save()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "用户信息更新成功",
	})
}

// SettingController 设置控制器
type SettingController struct{}

// GetSettings 获取系统设置
func (a *SettingController) GetSettings(c *gin.Context) {
	settingService := service.SettingService{}

	port, _ := settingService.GetPort()
	webBasePath, _ := settingService.GetBasePath()
	certFile, _ := settingService.GetCertFile()
	keyFile, _ := settingService.GetKeyFile()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"port":        port,
			"webBasePath": webBasePath,
			"certFile":    certFile,
			"keyFile":     keyFile,
		},
	})
}

// UpdateSettings 更新系统设置
func (a *SettingController) UpdateSettings(c *gin.Context) {
	var req struct {
		Port        int    `json:"port"`
		WebBasePath string `json:"webBasePath"`
		CertFile    string `json:"certFile"`
		KeyFile     string `json:"keyFile"`
	}

	err := c.ShouldBindJSON(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "请求参数无效",
		})
		return
	}

	settingService := service.SettingService{}

	if req.Port > 0 {
		err = settingService.SetPort(req.Port)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": "设置端口失败：" + err.Error(),
			})
			return
		}
	}

	if req.WebBasePath != "" {
		err = settingService.SetBasePath(req.WebBasePath)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": "设置网页基础路径失败：" + err.Error(),
			})
			return
		}
	}

	if req.CertFile != "" {
		err = settingService.SetCertFile(req.CertFile)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": "设置证书文件失败：" + err.Error(),
			})
			return
		}
	}

	if req.KeyFile != "" {
		err = settingService.SetKeyFile(req.KeyFile)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": "设置密钥文件失败：" + err.Error(),
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "设置更新成功",
		"data":    nil,
	})
}

// 以下是空的控制器实现，实际项目中需要完善

// InboundController 入站控制器
type InboundController struct{}

// GetInbounds 获取所有入站
func (a *InboundController) GetInbounds(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    []interface{}{},
	})
}

// AddInbound 添加入站
func (a *InboundController) AddInbound(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "添加入站成功",
	})
}

// UpdateInbound 更新入站
func (a *InboundController) UpdateInbound(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "更新入站成功",
	})
}

// DeleteInbound 删除入站
func (a *InboundController) DeleteInbound(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "删除入站成功",
	})
}

// ClientController 客户端控制器
type ClientController struct{}

// GetClients 获取所有客户端
func (a *ClientController) GetClients(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    []interface{}{},
	})
}

// AddClient 添加客户端
func (a *ClientController) AddClient(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "添加客户端成功",
	})
}

// UpdateClient 更新客户端
func (a *ClientController) UpdateClient(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "更新客户端成功",
	})
}

// DeleteClient 删除客户端
func (a *ClientController) DeleteClient(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "删除客户端成功",
	})
}

// ServerController 服务器控制器
type ServerController struct{}

// GetStatus 获取服务器状态
func (a *ServerController) GetStatus(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"status": "running",
		},
	})
}

// GetStats 获取服务器统计信息
func (a *ServerController) GetStats(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"cpu":        0.0,
			"mem":        0.0,
			"networkIn":  0,
			"networkOut": 0,
		},
	})
}

// XrayController Xray控制器
type XrayController struct{}

// Restart 重启Xray
func (a *XrayController) Restart(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Xray重启成功",
	})
}

// Stop 停止Xray
func (a *XrayController) Stop(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Xray停止成功",
	})
}

// Start 启动Xray
func (a *XrayController) Start(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Xray启动成功",
	})
}

// GetConfig 获取Xray配置
func (a *XrayController) GetConfig(c *gin.Context) {
	settingService := service.SettingService{}
	template, _ := settingService.GetXrayConfigTemplate()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"config": template,
		},
	})
} 