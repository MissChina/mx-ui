package web

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"mx-ui/config"
	"mx-ui/logger"
	"mx-ui/web/controller"
	"mx-ui/web/service"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-contrib/sessions"
	"github.com/gin-contrib/sessions/cookie"
	"github.com/gin-gonic/gin"
)

//go:embed web
var staticFS embed.FS

// Server Web服务器结构
type Server struct {
	httpServer *http.Server
	router     *gin.Engine
}

// NewServer 创建一个新的Web服务器
func NewServer() *Server {
	gin.SetMode(gin.ReleaseMode)
	router := gin.Default()

	// 设置静态文件路由
	staticSubFS, _ := fs.Sub(staticFS, "web")
	router.StaticFS("/static", http.FS(staticSubFS))

	// 使用Cookie存储session
	store := cookie.NewStore([]byte("mx-ui-secret"))
	router.Use(sessions.Sessions("mx-ui-session", store))

	// 注册路由器
	registerRoutes(router)

	return &Server{
		router: router,
	}
}

// Start 启动Web服务器
func (s *Server) Start() error {
	// 获取Web端口
	settingService := service.SettingService{}
	port, err := settingService.GetPort()
	if err != nil {
		port = config.GetDefaultWebPort()
	}

	// 获取证书文件
	certFile, err := settingService.GetCertFile()
	keyFile, err2 := settingService.GetKeyFile()

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", port),
		Handler: s.router,
	}

	// 判断是否使用HTTPS
	var startErr error
	if certFile != "" && keyFile != "" && err == nil && err2 == nil {
		// 检查文件是否存在
		if _, err := os.Stat(certFile); err == nil {
			if _, err := os.Stat(keyFile); err == nil {
				logger.Info("使用HTTPS启动Web服务器，端口:", port)
				go func() {
					startErr = s.httpServer.ListenAndServeTLS(certFile, keyFile)
					if startErr != nil && startErr != http.ErrServerClosed {
						logger.Error("启动HTTPS服务器失败:", startErr)
					}
				}()
				return nil
			}
		}
	}

	// 使用HTTP启动
	logger.Info("使用HTTP启动Web服务器，端口:", port)
	go func() {
		startErr = s.httpServer.ListenAndServe()
		if startErr != nil && startErr != http.ErrServerClosed {
			logger.Error("启动HTTP服务器失败:", startErr)
		}
	}()

	return nil
}

// Stop 停止Web服务器
func (s *Server) Stop() error {
	if s.httpServer != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return s.httpServer.Shutdown(ctx)
	}
	return nil
}

// registerRoutes 注册路由
func registerRoutes(router *gin.Engine) {
	// 验证中间件
	authMiddleware := controller.AuthMiddleware()

	// 基础API路由前缀
	apiPrefix := config.APIPrefix
	api := router.Group(apiPrefix)
	{
		// 登录相关API
		loginController := &controller.LoginController{}
		api.POST("/login", loginController.Login)
		api.POST("/logout", authMiddleware, loginController.Logout)

		// 需要验证的API
		api.Use(authMiddleware)
		{
			// 用户相关API
			userController := &controller.UserController{}
			api.GET("/user", userController.GetUser)
			api.PUT("/user", userController.UpdateUser)

			// 设置相关API
			settingController := &controller.SettingController{}
			api.GET("/settings", settingController.GetSettings)
			api.PUT("/settings", settingController.UpdateSettings)

			// 入站相关API
			inboundController := &controller.InboundController{}
			inboundAPI := api.Group("/inbounds")
			{
				inboundAPI.GET("", inboundController.GetInbounds)
				inboundAPI.POST("", inboundController.AddInbound)
				inboundAPI.PUT("/:id", inboundController.UpdateInbound)
				inboundAPI.DELETE("/:id", inboundController.DeleteInbound)
			}

			// 客户端相关API
			clientController := &controller.ClientController{}
			clientAPI := api.Group("/clients")
			{
				clientAPI.GET("", clientController.GetClients)
				clientAPI.POST("", clientController.AddClient)
				clientAPI.PUT("/:id", clientController.UpdateClient)
				clientAPI.DELETE("/:id", clientController.DeleteClient)
			}

			// 服务器状态API
			serverController := &controller.ServerController{}
			api.GET("/server/status", serverController.GetStatus)
			api.GET("/server/stats", serverController.GetStats)

			// Xray相关API
			xrayController := &controller.XrayController{}
			api.POST("/xray/restart", xrayController.Restart)
			api.POST("/xray/stop", xrayController.Stop)
			api.POST("/xray/start", xrayController.Start)
			api.GET("/xray/config", xrayController.GetConfig)
		}
	}

	// 前端路由
	router.NoRoute(func(c *gin.Context) {
		// API路由返回404
		if strings.HasPrefix(c.Request.URL.Path, apiPrefix) {
			c.JSON(http.StatusNotFound, gin.H{
				"success": false,
				"message": "接口不存在",
			})
			return
		}

		// 获取网页基础路径
		settingService := service.SettingService{}
		webBasePath, err := settingService.GetBasePath()
		if err != nil || webBasePath == "" {
			webBasePath = "/"
		}

		// 检查是否访问网页基础路径
		if !strings.HasPrefix(c.Request.URL.Path, webBasePath) {
			c.JSON(http.StatusNotFound, gin.H{
				"success": false,
				"message": "页面不存在",
			})
			return
		}

		// 返回index.html，由前端路由处理
		c.Header("Content-Type", "text/html")
		index, _ := staticFS.ReadFile("web/index.html")
		c.String(http.StatusOK, string(index))
	})
} 