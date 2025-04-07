# MX-UI Windows PowerShell打包脚本
# 警告：此脚本仅作为备用方案，生成的文件在Linux系统上可能会有编码问题
# 强烈建议在Linux系统上执行打包操作

Write-Host "===== MX-UI Windows打包脚本 =====" -ForegroundColor Green
Write-Host "警告：此脚本生成的包在Linux上可能有兼容性问题，建议在Linux环境下打包" -ForegroundColor Yellow

# 检查7zip是否安装
$use7z = $false
try {
    $7zPath = Get-Command "7z.exe" -ErrorAction Stop
    $use7z = $true
    Write-Host "检测到7zip，将使用它进行打包" -ForegroundColor Green
} catch {
    Write-Host "未检测到7zip，将尝试使用其他方法打包" -ForegroundColor Yellow
}

# 清理旧文件
Write-Host "1. 清理临时文件..." -ForegroundColor Cyan
Remove-Item -Path "temp_pkg" -Recurse -Force -ErrorAction SilentlyContinue

# 创建目录结构
Write-Host "2. 创建目录结构..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "temp_pkg/mx-ui/bin" -Force | Out-Null
New-Item -ItemType Directory -Path "temp_pkg/mx-ui/web/web" -Force | Out-Null

# 下载Xray二进制文件
Write-Host "3. 下载Xray二进制文件..." -ForegroundColor Cyan

# 创建下载函数
function Download-File {
    param (
        [string]$Url,
        [string]$OutFile
    )
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutFile)
        return $true
    } catch {
        Write-Host "下载失败: $Url" -ForegroundColor Red
        Write-Host "错误: $_" -ForegroundColor Red
        return $false
    }
}

# 下载amd64架构
$xrayAmd64Url = "https://github.com/XTLS/Xray-core/releases/download/v1.8.6/Xray-windows-64.zip"
$xrayAmd64File = "xray-amd64.zip"

Write-Host "   下载amd64架构Xray..." -ForegroundColor Cyan
if (Download-File -Url $xrayAmd64Url -OutFile $xrayAmd64File) {
    # 解压
    if ($use7z) {
        & 7z x $xrayAmd64File -otemp_xray_amd64 -y | Out-Null
    } else {
        Expand-Archive -Path $xrayAmd64File -DestinationPath "temp_xray_amd64" -Force
    }
    
    # 复制并重命名为Linux格式
    Copy-Item -Path "temp_xray_amd64/xray.exe" -Destination "temp_pkg/mx-ui/bin/xray-linux-amd64" -Force
    
    # 清理
    Remove-Item -Path "temp_xray_amd64" -Recurse -Force
    Remove-Item -Path $xrayAmd64File -Force
    
    Write-Host "   amd64架构Xray下载完成" -ForegroundColor Green
} else {
    # 创建占位符文件
    Set-Content -Path "temp_pkg/mx-ui/bin/xray-linux-amd64" -Value "echo 'This is a placeholder for amd64 xray'"
    Write-Host "   创建amd64架构Xray占位符" -ForegroundColor Yellow
}

# 为其他架构创建占位符
Set-Content -Path "temp_pkg/mx-ui/bin/xray-linux-arm64" -Value "echo 'This is a placeholder for arm64 xray'"
Write-Host "   创建arm64架构Xray占位符" -ForegroundColor Yellow

Set-Content -Path "temp_pkg/mx-ui/bin/xray-linux-s390x" -Value "echo 'This is a placeholder for s390x xray'"
Write-Host "   创建s390x架构Xray占位符" -ForegroundColor Yellow

# 创建mx-ui可执行文件占位符
Write-Host "4. 创建mx-ui可执行文件占位符..." -ForegroundColor Cyan
Set-Content -Path "temp_pkg/mx-ui/mx-ui" -Value "#!/bin/sh`necho 'This is a placeholder for mx-ui executable'"

# 复制核心文件
Write-Host "5. 复制核心文件..." -ForegroundColor Cyan
Copy-Item -Path "../mx-ui.service" -Destination "temp_pkg/mx-ui/" -Force
Copy-Item -Path "../install.sh" -Destination "temp_pkg/mx-ui/" -Force
Copy-Item -Path "../mx-ui.sh" -Destination "temp_pkg/mx-ui/mx-ui-script" -Force

# 复制网页文件
Write-Host "6. 复制网页文件..." -ForegroundColor Cyan
Copy-Item -Path "../web/web/index.html" -Destination "temp_pkg/mx-ui/web/web/" -Force
Copy-Item -Path "../web/web/login.html" -Destination "temp_pkg/mx-ui/web/web/" -Force

# 创建打包
Write-Host "7. 创建打包文件..." -ForegroundColor Cyan

# 定义要打包的架构
$archs = @("amd64", "arm64", "s390x")

foreach ($arch in $archs) {
    $outputFile = "mx-ui-linux-$arch.tar.gz"
    Write-Host "   打包 $outputFile..." -ForegroundColor Cyan
    
    if ($use7z) {
        # 使用7zip打包
        Push-Location "temp_pkg"
        & 7z a -ttar "mx-ui-$arch.tar" "mx-ui" -y | Out-Null
        & 7z a -tgzip "../$outputFile" "mx-ui-$arch.tar" -y | Out-Null
        Remove-Item -Path "mx-ui-$arch.tar" -Force
        Pop-Location
    } else {
        # 提示无法打包
        Write-Host "   无法打包 $outputFile，未安装7zip" -ForegroundColor Red
        Write-Host "   请安装7zip后重试，或在Linux环境下执行打包" -ForegroundColor Red
        continue
    }
    
    Write-Host "   $outputFile 打包完成" -ForegroundColor Green
}

# 清理临时文件
Write-Host "8. 清理临时文件..." -ForegroundColor Cyan
Remove-Item -Path "temp_pkg" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "===== 打包完成 =====" -ForegroundColor Green
Write-Host "生成的文件位于当前目录" -ForegroundColor Green
Get-ChildItem -Path "mx-ui-linux-*.tar.gz"

Write-Host "`n重要提示：" -ForegroundColor Yellow
Write-Host "1. 此脚本生成的文件仅供测试使用" -ForegroundColor Yellow
Write-Host "2. 在Linux系统上可能会遇到编码或权限问题" -ForegroundColor Yellow
Write-Host "3. 强烈建议在Linux环境下使用linux_package.sh进行打包" -ForegroundColor Yellow 