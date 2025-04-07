这个目录用于存放构建后的发布文件（mx-ui-linux-*.tar.gz）。

由于在Windows上创建的tar.gz文件可能在Linux系统上解压时出现编码问题，建议直接在Linux系统上执行打包操作：

1. 将整个mx-ui项目复制到Linux系统
2. 确保安装了Go环境和git
3. 进入项目目录，执行：

```bash
# 安装xray核心文件到bin目录
mkdir -p bin
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.6/Xray-linux-64.zip -O xray.zip
unzip xray.zip -d temp
mv temp/xray bin/xray-linux-amd64
chmod +x bin/xray-linux-amd64
rm -rf temp xray.zip

# 为其他架构也下载xray
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.6/Xray-linux-arm64-v8a.zip -O xray-arm64.zip
unzip xray-arm64.zip -d temp
mv temp/xray bin/xray-linux-arm64
chmod +x bin/xray-linux-arm64
rm -rf temp xray-arm64.zip

# 执行build.sh脚本进行打包
chmod +x build.sh
./build.sh
```

这将生成以下文件:
- mx-ui-linux-amd64.tar.gz
- mx-ui-linux-arm64.tar.gz
- mx-ui-linux-s390x.tar.gz

然后可以将这些文件用于发布或安装。 