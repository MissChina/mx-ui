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
		api.POST("/login", controller.LoginController{}.Login)
		api.POST("/logout", authMiddleware, controller.LoginController{}.Logout)

		// 需要验证的API
		api.Use(authMiddleware)
		{
			// 用户相关API
			api.GET("/user", controller.UserController{}.GetUser)
			api.PUT("/user", controller.UserController{}.UpdateUser)

			// 设置相关API
			api.GET("/settings", controller.SettingController{}.GetSettings)
			api.PUT("/settings", controller.SettingController{}.UpdateSettings)

			// 入站相关API
			inboundAPI := api.Group("/inbounds")
			{
				inboundAPI.GET("", controller.InboundController{}.GetInbounds)
				inboundAPI.POST("", controller.InboundController{}.AddInbound)
				inboundAPI.PUT("/:id", controller.InboundController{}.UpdateInbound)
				inboundAPI.DELETE("/:id", controller.InboundController{}.DeleteInbound)
			}

			// 客户端相关API
			clientAPI := api.Group("/clients")
			{
				clientAPI.GET("", controller.ClientController{}.GetClients)
				clientAPI.POST("", controller.ClientController{}.AddClient)
				clientAPI.PUT("/:id", controller.ClientController{}.UpdateClient)
				clientAPI.DELETE("/:id", controller.ClientController{}.DeleteClient)
			}

			// 服务器状态API
			api.GET("/server/status", controller.ServerController{}.GetStatus)
			api.GET("/server/stats", controller.ServerController{}.GetStats)

			// Xray相关API
			api.POST("/xray/restart", controller.XrayController{}.Restart)
			api.POST("/xray/stop", controller.XrayController{}.Stop)
			api.POST("/xray/start", controller.XrayController{}.Start)
			api.GET("/xray/config", controller.XrayController{}.GetConfig)
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