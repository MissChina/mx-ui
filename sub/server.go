package sub

import (
	"fmt"
	"mx-ui/config"
	"mx-ui/logger"
	"net/http"
	"time"
)

// Server 订阅服务器
type Server struct {
	httpServer *http.Server
	router     *http.ServeMux
}

// NewServer 创建一个新的订阅服务器
func NewServer() *Server {
	mux := http.NewServeMux()

	// 注册路由
	mux.HandleFunc("/sub/", handleSub)

	return &Server{
		router: mux,
	}
}

// Start 启动订阅服务器
func (s *Server) Start() error {
	// 使用与Web服务器相同的端口
	port := config.GetDefaultWebPort()

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", port),
		Handler: s.router,
	}

	// 启动HTTP服务器
	go func() {
		logger.Info("订阅服务器已启动")
		err := s.httpServer.ListenAndServe()
		if err != nil && err != http.ErrServerClosed {
			logger.Error("订阅服务器错误:", err)
		}
	}()

	return nil
}

// Stop 停止订阅服务器
func (s *Server) Stop() error {
	if s.httpServer != nil {
		logger.Info("停止订阅服务器")
		return s.httpServer.Close()
	}
	return nil
}

// handleSub 处理订阅请求
func handleSub(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Path[5:] // 去除 "/sub/" 前缀
	if token == "" {
		http.Error(w, "订阅令牌无效", http.StatusBadRequest)
		return
	}

	// 在实际项目中，这里应该根据token查询数据库获取相应的节点信息
	// 并生成对应的配置文件
	
	// 示例内容
	resp := fmt.Sprintf("订阅内容示例 - 生成时间: %s", time.Now().Format("2006-01-02 15:04:05"))
	
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Write([]byte(resp))
} 