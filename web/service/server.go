package service

import (
	"mx-ui/database"
	"mx-ui/logger"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
	"github.com/shirou/gopsutil/v3/process"
)

type ProcessState string

const (
	Running ProcessState = "running"
	Stop    ProcessState = "stop"
	Error   ProcessState = "error"
)

// 定义网络连接类型常量
const (
	TCP  uint32 = 1
	TCP4 uint32 = 2
	TCP6 uint32 = 3
	UDP  uint32 = 4
	UDP4 uint32 = 5
	UDP6 uint32 = 6
)

// Status 系统状态结构体
type Status struct {
	T   time.Time `json:"-"`
	Cpu float64   `json:"cpu"`
	Mem struct {
		Current uint64 `json:"current"`
		Total   uint64 `json:"total"`
	} `json:"mem"`
	Swap struct {
		Current uint64 `json:"current"`
		Total   uint64 `json:"total"`
	} `json:"swap"`
	Disk struct {
		Current uint64 `json:"current"`
		Total   uint64 `json:"total"`
	} `json:"disk"`
	Xray struct {
		State    ProcessState `json:"state"`
		ErrorMsg string       `json:"errorMsg"`
		Version  string       `json:"version"`
	} `json:"xray"`
	Uptime     uint64    `json:"uptime"`
	Loads      []float64 `json:"loads"`
	TcpCount   int       `json:"tcpCount"`
	UdpCount   int       `json:"udpCount"`
	NetIO      struct {
		Up   uint64 `json:"up"`
		Down uint64 `json:"down"`
	} `json:"netIO"`
	NetTraffic struct {
		Sent uint64 `json:"sent"`
		Recv uint64 `json:"recv"`
	} `json:"netTraffic"`
}

// ServerService 服务器相关服务
type ServerService struct {
	lastStatus        *Status
	lastGetStatusTime time.Time
}

// GetServerStats 获取服务器详细统计信息
func (s *ServerService) GetServerStats() (*database.ServerStat, error) {
	status := s.GetStatus(nil)
	
	// 查询最新的统计数据
	var serverStat database.ServerStat
	err := database.DB.Order("created_at DESC").First(&serverStat).Error
	if err != nil {
		// 如果没有数据，创建新的统计数据
		serverStat = database.ServerStat{
			Date:       time.Now().Format("2006-01-02"),
			CPU:        status.Cpu,
			Mem:        float64(status.Mem.Current) / float64(status.Mem.Total) * 100,
			NetworkIn:  int64(status.NetTraffic.Recv),
			NetworkOut: int64(status.NetTraffic.Sent),
		}
		database.DB.Create(&serverStat)
	}
	
	return &serverStat, nil
}

// GetStatus 获取系统状态
func (s *ServerService) GetStatus(lastStatus *Status) *Status {
	now := time.Now()
	status := &Status{
		T: now,
	}

	// CPU信息
	percents, err := cpu.Percent(0, false)
	if err != nil {
		logger.Warning("获取CPU占用率失败:", err)
	} else if len(percents) > 0 {
		status.Cpu = percents[0]
	}

	// 系统运行时间
	upTime, err := host.Uptime()
	if err != nil {
		logger.Warning("获取系统运行时间失败:", err)
	} else {
		status.Uptime = upTime
	}

	// 内存信息
	memInfo, err := mem.VirtualMemory()
	if err != nil {
		logger.Warning("获取内存信息失败:", err)
	} else {
		status.Mem.Current = memInfo.Used
		status.Mem.Total = memInfo.Total
	}

	// 交换分区信息
	swapInfo, err := mem.SwapMemory()
	if err != nil {
		logger.Warning("获取交换分区信息失败:", err)
	} else {
		status.Swap.Current = swapInfo.Used
		status.Swap.Total = swapInfo.Total
	}

	// 磁盘信息
	diskInfo, err := disk.Usage("/")
	if err != nil {
		logger.Warning("获取磁盘信息失败:", err)
	} else {
		status.Disk.Current = diskInfo.Used
		status.Disk.Total = diskInfo.Total
	}

	// 系统负载
	avgState, err := load.Avg()
	if err != nil {
		logger.Warning("获取系统负载失败:", err)
	} else {
		status.Loads = []float64{avgState.Load1, avgState.Load5, avgState.Load15}
	}

	// 网络流量
	ioStats, err := net.IOCounters(false)
	if err != nil {
		logger.Warning("获取网络流量失败:", err)
	} else if len(ioStats) > 0 {
		ioStat := ioStats[0]
		status.NetTraffic.Sent = ioStat.BytesSent
		status.NetTraffic.Recv = ioStat.BytesRecv

		if lastStatus != nil {
			duration := now.Sub(lastStatus.T)
			seconds := float64(duration) / float64(time.Second)
			up := uint64(float64(status.NetTraffic.Sent-lastStatus.NetTraffic.Sent) / seconds)
			down := uint64(float64(status.NetTraffic.Recv-lastStatus.NetTraffic.Recv) / seconds)
			status.NetIO.Up = up
			status.NetIO.Down = down
		}
	} else {
		logger.Warning("未找到网络接口")
	}

	// 获取TCP/UDP连接数
	connections, err := net.Connections("all")
	if err != nil {
		logger.Warning("获取网络连接信息失败:", err)
	} else {
		tcpCount := 0
		udpCount := 0
		for _, conn := range connections {
			switch conn.Type {
			case TCP, TCP4, TCP6:
				tcpCount++
			case UDP, UDP4, UDP6:
				udpCount++
			}
		}
		status.TcpCount = tcpCount
		status.UdpCount = udpCount
	}

	// Xray状态
	// 这里应该检查xray进程状态，现在仅作为示例
	p, err := process.NewProcess(int32(0))
	if err != nil {
		status.Xray.State = Stop
	} else {
		name, err := p.Name()
		if err != nil || name != "xray" {
			status.Xray.State = Stop
		} else {
			status.Xray.State = Running
			status.Xray.Version = "1.8.0" // 这里应该获取实际xray版本
		}
	}

	// 更新最后一次状态
	s.lastStatus = status
	s.lastGetStatusTime = now
	
	return status
} 