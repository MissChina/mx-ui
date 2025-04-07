#!/bin/bash

# 定义版本
COMMIT=$(git rev-parse --short HEAD)
VERSION=$(grep -o 'Version.*=.*".*"' config/config.go | awk -F'"' '{print $2}')
DATE=$(date -u +%Y%m%d)

# 构建目录
BUILD_DIR="release"
mkdir -p ${BUILD_DIR}

# 清理旧的构建文件
rm -rf ${BUILD_DIR}/*

# 定义要构建的架构
ARCHS=(
    "linux,amd64" 
    "linux,arm64" 
    "linux,s390x"
)

# 打包函数
build_xui() {
    local os=$1
    local arch=$2
    local output="mx-ui-${os}-${arch}"
    
    echo "构建 ${output}"
    
    # 设置 Go 环境变量
    export GOOS=${os}
    export GOARCH=${arch}
    
    # 构建主程序
    go build -ldflags "-s -w -X mx-ui/config.Version=${VERSION}-${DATE} -X mx-ui/config.BuildDate=${DATE} -X mx-ui/config.CommitID=${COMMIT}" -o ${BUILD_DIR}/mx-ui main.go
    
    # 创建临时目录并复制文件
    mkdir -p ${BUILD_DIR}/temp/mx-ui/bin
    cp ${BUILD_DIR}/mx-ui ${BUILD_DIR}/temp/mx-ui/
    cp install.sh ${BUILD_DIR}/temp/mx-ui/
    cp mx-ui.service ${BUILD_DIR}/temp/mx-ui/
    cp mx-ui.sh ${BUILD_DIR}/temp/mx-ui/ && mv ${BUILD_DIR}/temp/mx-ui/mx-ui.sh ${BUILD_DIR}/temp/mx-ui/mx-ui-script
    
    # 复制 Xray 二进制文件（如果有）
    if [ -f "bin/xray-${os}-${arch}" ]; then
        cp bin/xray-${os}-${arch} ${BUILD_DIR}/temp/mx-ui/bin/
    else
        echo "警告: bin/xray-${os}-${arch} 不存在，跳过"
    fi
    
    # 在临时目录中打包
    cd ${BUILD_DIR}/temp
    
    # 创建 tar.gz 文件
    tar -czvf ../${output}.tar.gz mx-ui
    
    # 返回到原目录
    cd ../../
    
    # 清理临时目录
    rm -rf ${BUILD_DIR}/temp
    rm -f ${BUILD_DIR}/mx-ui
    
    echo "构建 ${output} 完成"
}

# 主构建过程
for item in "${ARCHS[@]}"
do
    IFS=',' read -r -a array <<< "$item"
    os=${array[0]}
    arch=${array[1]}
    build_xui $os $arch
done

echo "所有构建任务完成，输出文件在 ${BUILD_DIR} 目录" 