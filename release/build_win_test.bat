@echo off
echo 创建临时测试包 - 仅用于测试，不建议用于正式发布
echo 警告: 此脚本只生成测试用的tar.gz文件，在Linux上可能无法正常解压

REM 创建临时文件夹
mkdir test_package\mx-ui\bin
mkdir test_package\mx-ui\web\web

REM 复制主要文件
copy ..\mx-ui.service test_package\mx-ui\
copy ..\install.sh test_package\mx-ui\
copy ..\mx-ui.sh test_package\mx-ui\mx-ui-script

REM 复制网页文件
copy ..\web\web\index.html test_package\mx-ui\web\web\
copy ..\web\web\login.html test_package\mx-ui\web\web\

REM 创建一个模拟的可执行文件
echo echo "mx-ui v1.0.0 模拟版本" > test_package\mx-ui\mx-ui
echo echo "用于测试安装脚本，此文件不是真正的可执行文件" >> test_package\mx-ui\mx-ui

REM 创建模拟xray
echo echo "这是一个模拟的xray程序" > test_package\mx-ui\bin\xray-linux-amd64

REM 尝试创建tar.gz文件 (需要安装7-Zip或Git Bash)
echo 正在创建压缩包...
where 7z >nul 2>&1
if %errorlevel% equ 0 (
    cd test_package
    7z a -ttar mx-ui.tar mx-ui
    7z a -tgzip ..\mx-ui-linux-amd64.tar.gz mx-ui.tar
    cd ..
    echo 压缩包已创建: mx-ui-linux-amd64.tar.gz
) else (
    echo 未找到7z命令，请安装7-Zip或使用Git Bash执行打包
    echo 如果使用Git Bash，请运行:
    echo cd test_package
    echo tar -czvf ../mx-ui-linux-amd64.tar.gz mx-ui
)

echo.
echo 测试包创建完成。请注意：
echo 1. 此包仅用于测试install.sh脚本的流程
echo 2. 不包含真正的可执行文件
echo 3. 不建议用于正式发布
echo 4. 如需正式发布，请在Linux环境下执行完整的build.sh脚本 