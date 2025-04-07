#!/bin/bash

# mx-ui Linux一键打包脚本
# 此脚本应在Linux环境下运行，以确保生成的tar.gz文件在Linux系统上能正常解压使用

set -e

echo "===== MX-UI Linux打包脚本 ====="
echo "此脚本将下载xray核心并执行打包操作"

# 创建必要的目录
echo "1. 创建必要目录"
mkdir -p bin
mkdir -p release

# 下载xray核心
echo "2. 下载xray核心文件"

# amd64架构
echo "   下载 amd64 架构 xray..."
wget -q -O xray-amd64.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.6/Xray-linux-64.zip
mkdir -p temp_amd64
unzip -q xray-amd64.zip -d temp_amd64
mv temp_amd64/xray bin/xray-linux-amd64
chmod +x bin/xray-linux-amd64
rm -rf temp_amd64 xray-amd64.zip
echo "   amd64 架构 xray 下载完成"

# arm64架构
echo "   下载 arm64 架构 xray..."
wget -q -O xray-arm64.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.6/Xray-linux-arm64-v8a.zip
mkdir -p temp_arm64
unzip -q xray-arm64.zip -d temp_arm64
mv temp_arm64/xray bin/xray-linux-arm64
chmod +x bin/xray-linux-arm64
rm -rf temp_arm64 xray-arm64.zip
echo "   arm64 架构 xray 下载完成"

# s390x架构 (Xray可能不提供s390x的预编译版本，这里只是作为示例)
echo "   注意: s390x架构可能需要手动编译xray"
touch bin/xray-linux-s390x
chmod +x bin/xray-linux-s390x
echo "#!/bin/sh" > bin/xray-linux-s390x
echo "echo 'This is a placeholder for s390x xray. Please compile it manually.'" >> bin/xray-linux-s390x

# 执行打包
echo "3. 执行打包操作"
chmod +x build.sh
./build.sh

echo "4. 打包完成"
echo "   生成的文件位于 release 目录下"
ls -la release/

echo "===== 打包完成 ====="
echo "您现在可以将release目录下的tar.gz文件用于发布或安装" 