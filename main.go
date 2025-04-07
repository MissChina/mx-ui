package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"mx-ui/config"
	"mx-ui/database"
	"mx-ui/logger"
	"mx-ui/sub"
	"mx-ui/web"
	"mx-ui/web/global"
	"mx-ui/web/service"

	"github.com/op/go-logging"
)

func runWebServer() {
	log.Printf("启动 %v %v", config.GetName(), config.GetVersion())

	switch config.GetLogLevel() {
	case config.Debug:
		logger.InitLogger(logging.DEBUG)
	case config.Info:
		logger.InitLogger(logging.INFO)
	case config.Notice:
		logger.InitLogger(logging.NOTICE)
	case config.Warn:
		logger.InitLogger(logging.WARNING)
	case config.Error:
		logger.InitLogger(logging.ERROR)
	default:
		log.Fatalf("未知日志级别: %v", config.GetLogLevel())
	}

	err := database.InitDB(config.GetDBPath())
	if err != nil {
		log.Fatalf("数据库初始化错误: %v", err)
	}

	var server *web.Server
	server = web.NewServer()
	global.SetWebServer(server)
	err = server.Start()
	if err != nil {
		log.Fatalf("Web服务器启动错误: %v", err)
		return
	}

	var subServer *sub.Server
	subServer = sub.NewServer()
	global.SetSubServer(subServer)
	err = subServer.Start()
	if err != nil {
		log.Fatalf("订阅服务器启动错误: %v", err)
		return
	}

	sigCh := make(chan os.Signal, 1)
	// 捕获关闭信号
	signal.Notify(sigCh, syscall.SIGHUP, syscall.SIGTERM)
	for {
		sig := <-sigCh

		switch sig {
		case syscall.SIGHUP:
			logger.Info("收到SIGHUP信号，重启服务器...")

			err := server.Stop()
			if err != nil {
				logger.Debug("停止Web服务器时出错:", err)
			}
			err = subServer.Stop()
			if err != nil {
				logger.Debug("停止订阅服务器时出错:", err)
			}

			server = web.NewServer()
			global.SetWebServer(server)
			err = server.Start()
			if err != nil {
				log.Fatalf("重启Web服务器出错: %v", err)
				return
			}
			log.Println("Web服务器重启成功")

			subServer = sub.NewServer()
			global.SetSubServer(subServer)
			err = subServer.Start()
			if err != nil {
				log.Fatalf("重启订阅服务器出错: %v", err)
				return
			}
			log.Println("订阅服务器重启成功")

		default:
			server.Stop()
			subServer.Stop()
			log.Println("服务器关闭中")
			return
		}
	}
}

func resetSetting() {
	err := database.InitDB(config.GetDBPath())
	if err != nil {
		fmt.Println("数据库初始化失败:", err)
		return
	}

	settingService := service.SettingService{}
	err = settingService.ResetSettings()
	if err != nil {
		fmt.Println("重置设置失败:", err)
	} else {
		fmt.Println("设置重置成功")
	}
}

func showSetting(show bool) {
	if show {
		settingService := service.SettingService{}
		port, err := settingService.GetPort()
		if err != nil {
			fmt.Println("获取当前端口失败，错误信息:", err)
		}

		webBasePath, err := settingService.GetBasePath()
		if err != nil {
			fmt.Println("获取网页基础路径失败，错误信息:", err)
		}

		certFile, err := settingService.GetCertFile()
		if err != nil {
			fmt.Println("获取证书文件失败，错误信息:", err)
		}
		keyFile, err := settingService.GetKeyFile()
		if err != nil {
			fmt.Println("获取密钥文件失败，错误信息:", err)
		}

		userService := service.UserService{}
		userModel, err := userService.GetFirstUser()
		if err != nil {
			fmt.Println("获取当前用户信息失败，错误信息:", err)
		}

		username := userModel.Username
		userpasswd := userModel.Password
		if username == "" || userpasswd == "" {
			fmt.Println("当前用户名或密码为空")
		}

		fmt.Println("当前面板设置如下:")
		if certFile == "" || keyFile == "" {
			fmt.Println("警告: 面板未使用SSL进行安全保护")
		} else {
			fmt.Println("面板已使用SSL进行安全保护")
		}
		fmt.Println("用户名:", username)
		fmt.Println("密码:", userpasswd)
		fmt.Println("端口:", port)
		fmt.Println("网页基础路径:", webBasePath)
	}
}

func updateSetting(port int, username string, password string, webBasePath string) {
	err := database.InitDB(config.GetDBPath())
	if err != nil {
		fmt.Println("初始化数据库错误:", err)
		return
	}

	settingService := service.SettingService{}
	
	if port > 0 {
		err := settingService.SetPort(port)
		if err != nil {
			fmt.Printf("设置端口错误: %v\n", err)
		} else {
			fmt.Printf("端口设置为: %v\n", port)
		}
	}
	
	if username != "" && password != "" {
		userService := service.UserService{}
		err := userService.UpdateFirstUser(username, password)
		if err != nil {
			fmt.Printf("更新用户错误: %v\n", err)
		} else {
			fmt.Printf("用户更新为: %v\n", username)
		}
	}

	if webBasePath != "" {
		err := settingService.SetBasePath(webBasePath)
		if err != nil {
			fmt.Printf("设置网页基础路径错误: %v\n", err)
		} else {
			fmt.Printf("网页基础路径设置为: %v\n", webBasePath)
		}
	}
}

func migrateDb() {
	err := database.InitDB(config.GetDBPath())
	if err != nil {
		fmt.Println("初始化数据库错误:", err)
		return
	}
	fmt.Println("数据库迁移完成")
}

func main() {
	if len(os.Args) < 2 {
		runWebServer()
		return
	}

	var showVersion bool
	flag.BoolVar(&showVersion, "v", false, "显示版本")
	flag.BoolVar(&showVersion, "version", false, "显示版本")
	
	runCmd := flag.NewFlagSet("run", flag.ExitOnError)
	
	settingCmd := flag.NewFlagSet("setting", flag.ExitOnError)
	var port int
	var username, password, webBasePath string
	var showSettingInfo bool
	settingCmd.IntVar(&port, "port", 0, "面板端口")
	settingCmd.StringVar(&username, "username", "", "用户名")
	settingCmd.StringVar(&password, "password", "", "密码")
	settingCmd.StringVar(&webBasePath, "webBasePath", "", "网页基础路径")
	settingCmd.BoolVar(&showSettingInfo, "show", false, "显示设置信息")
	
	resetCmd := flag.NewFlagSet("reset", flag.ExitOnError)
	
	migrateCmd := flag.NewFlagSet("migrate", flag.ExitOnError)

	flag.Parse()
	
	if showVersion {
		fmt.Printf("%v %v\n", config.GetName(), config.GetVersion())
		return
	}

	switch os.Args[1] {
	case "run":
		_ = runCmd.Parse(os.Args[2:])
		runWebServer()
	case "setting":
		_ = settingCmd.Parse(os.Args[2:])
		if showSettingInfo {
			showSetting(showSettingInfo)
		} else {
			updateSetting(port, username, password, webBasePath)
		}
	case "reset":
		_ = resetCmd.Parse(os.Args[2:])
		resetSetting()
	case "migrate":
		_ = migrateCmd.Parse(os.Args[2:])
		migrateDb()
	default:
		fmt.Println("未知命令:", os.Args[1])
	}
} 