package global

import (
	"mx-ui/sub"
	"mx-ui/web"
)

var (
	webServer *web.Server
	subServer *sub.Server
)

// SetWebServer 设置Web服务器
func SetWebServer(server *web.Server) {
	webServer = server
}

// GetWebServer 获取Web服务器
func GetWebServer() *web.Server {
	return webServer
}

// SetSubServer 设置订阅服务器
func SetSubServer(server *sub.Server) {
	subServer = server
}

// GetSubServer 获取订阅服务器
func GetSubServer() *sub.Server {
	return subServer
} 