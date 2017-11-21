# one-key-docker-app
离线环境下一键安装docker环境，并启动docker应用。

**目前只适用于centos7.2**

1.脚本安装了yum repo的服务，默认端口为81，可在脚本开始修改。可将需要的rpm包放到./yumRepo/中，启动后可用yum命令安装。
2.docker registry取消掉了，可将注释去掉启动的时候也会启动docker registry。
3.脚本中写了两个docker app的例子，一个是mysql，另外一个是tomcat。

# 启动
查看脚本，修改docker相关参数并将tomcat war拷贝到./data/tomcat/webapps下面。
```bash
chmod +x start.sh
./start.sh
```