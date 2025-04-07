@echo off
setlocal enabledelayedexpansion

echo MX-UI Windows 安装脚本
echo ====================

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 错误: 请右键以管理员身份运行此脚本
    pause
    exit /b 1
)

:: 设置安装目录
set INSTALL_DIR=%ProgramFiles%\mx-ui
if exist %INSTALL_DIR% (
    echo 发现已有安装，将先卸载...
    call :uninstall
)

:: 创建安装目录
mkdir %INSTALL_DIR%
if %errorLevel% neq 0 (
    echo 创建安装目录失败
    pause
    exit /b 1
)

echo 安装目录: %INSTALL_DIR%

:: 检测系统架构
set ARCH=amd64
if exist "%ProgramFiles(x86)%" (
    set ARCH=amd64
) else (
    set ARCH=386
)
echo 系统架构: %ARCH%

:: 查找安装包
set PACKAGE=mx-ui-windows-%ARCH%.zip
if not exist %PACKAGE% (
    echo 错误: 找不到安装包 %PACKAGE%
    echo 请确保安装包与此脚本在同一目录
    pause
    exit /b 1
)

:: 解压文件
echo 解压安装包...
powershell -command "Expand-Archive -Force '%PACKAGE%' '%INSTALL_DIR%'"
if %errorLevel% neq 0 (
    echo 解压安装包失败
    pause
    exit /b 1
)

:: 创建数据目录
set DATA_DIR=%USERPROFILE%\mx-ui
if not exist %DATA_DIR% (
    mkdir %DATA_DIR%
)

:: 创建配置
echo 设置初始配置...
set /p PORT="输入面板端口 (默认: 54321): "
if "!PORT!"=="" set PORT=54321

set /p USERNAME="输入面板用户名 (默认: admin): "
if "!USERNAME!"=="" set USERNAME=admin

set /p PASSWORD="输入面板密码 (默认: admin): "
if "!PASSWORD!"=="" set PASSWORD=admin

:: 创建服务
echo 安装服务...
sc create mx-ui binPath= "%INSTALL_DIR%\mx-ui.exe" DisplayName= "MX-UI Panel" start= auto
if %errorLevel% neq 0 (
    echo 安装服务失败
    pause
    exit /b 1
)

:: 启动服务
echo 启动服务...
sc start mx-ui
if %errorLevel% neq 0 (
    echo 启动服务失败，请手动启动
)

:: 创建快捷方式
echo 创建快捷方式...
powershell -command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\MX-UI Panel.lnk'); $Shortcut.TargetPath = 'http://localhost:!PORT!'; $Shortcut.Save()"

echo.
echo 安装完成!
echo 面板访问地址: http://localhost:%PORT%
echo 用户名: %USERNAME%
echo 密码: %PASSWORD%
echo.
echo 已在桌面创建快捷方式，点击即可访问面板
echo.
pause
exit /b 0

:uninstall
echo 停止服务...
sc stop mx-ui
echo 删除服务...
sc delete mx-ui
echo 删除文件...
rmdir /s /q %INSTALL_DIR%
echo 卸载完成
goto :eof 