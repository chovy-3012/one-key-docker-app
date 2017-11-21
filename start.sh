#!/bin/bash
##user var
yumServerPort=81
##registry
###可选registryServerPort=5000

##constants
##createRepo
yumRepo=$(pwd)/yumRepo
createrepoRpmDir=$(pwd)/resources/rpm/
##registry
###可选registryFile=$(pwd)/resources/registry.tar.gz
###可选registryImage=192.168.1.106:5000/registry:2.5.0-rc.1
###可选registryDataDir=$(pwd)/registryRepo
##other



function main(){
set -e
echo " <<========================= step1 :create yum repo index =========================>> "
createYumRepoIndex
echo " <<========================= step2 :create local yum repo =========================>> "
createLocalYumRepo
echo " <<========================= step3 :start yum repo server =========================>> "
startYumRepoServer
echo " <<========================= step4 :start docker ==================================>> "
startDocker
##echo " <<========================= step5 :start registry ================================>> " 
##startRegistry
echo " <<========================= step5 :start docker app ==============================>> "
startDockerApp
echo " <<========================= htdc face install done! ==============================>> "
}



function createYumRepoIndex(){
rpm -ivh --quiet --force ${createrepoRpmDir}/deltarpm*
rpm -ivh --quiet --force ${createrepoRpmDir}/libxml2*
rpm -ivh --quiet --force ${createrepoRpmDir}/libxml2-python*
rpm -ivh --quiet --force ${createrepoRpmDir}/python-deltarpm*
rpm -ivh --quiet --force ${createrepoRpmDir}/createrepo*
createrepo -pdo ${yumRepo} ${yumRepo}
}

function createLocalYumRepo(){
touch /etc/yum.repos.d/htdc.repo
cat > /etc/yum.repos.d/htdc.repo <<EOF
[htdc-base]
name=htdc-base
baseurl=file://${yumRepo}
gpgcheck=0
EOF
repoBase="/etc/yum.repos.d/CentOS-Base.repo"
if [ -f "${repoBase}" ];then
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
fi
}

function setParam(){
if grep -q "$1" $3
then
sed -i  "/$1/c\\$1$2" $3
sed -i 's/\r//g' $3
else
echo -e "\n$1$2" >> $3
sed -i 's/\r//g' $3
fi
}

function startYumRepoServer(){
##install httpd
yum install -y -q httpd
# update port
sed -i "s/^Listen.*/Listen ${yumServerPort}/g" /etc/httpd/conf/httpd.conf
systemctl enable httpd.service
service httpd restart
##update yumRepo
yumRepoPath="/var/www/html"
mkdir -p ${yumRepoPath}
\cp -rf ${yumRepo}/* ${yumRepoPath}
createrepo -pdo ${yumRepoPath} ${yumRepoPath}
touch /etc/yum.repos.d/htdc.repo
cat > /etc/yum.repos.d/htdc.repo <<EOF
[htdc-base]
name=htdc-base
baseurl=file://${yumRepoPath}
gpgcheck=0
EOF
repoBase="/etc/yum.repos.d/CentOS-Base.repo"
if [ -f "${repoBase}" ];then
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
fi
## install dstat
yum install -y -q dstat
}

function startDocker(){
##check docker.service running
set +e
ds=$(service docker status)
if [[ $ds =~ "not-found" ]]
then
echo "install docker and start docker"
yum install -y -q docker-engine
systemctl enable docker.service
service docker start
else
echo "start docker"
systemctl enable docker.service
service docker start
fi
set -e
}

function startRegistry(){
sed -i "s/^ExecStart=.*/ExecStart=\/usr\/bin\/docker daemon -H fd:\/\/ --insecure-registry ${localIp}:${registryServerPort}/g" /usr/lib/systemd/system/docker.service
systemctl daemon-reload
service docker restart
docker load < ${registryFile}
docker run -d -v ${registryDataDir}:/var/lib/registry -p ${registryServerPort}:5000 --restart=always --name registry ${registryImage}
sleep 5
}

function startDockerApp(){
echo " <---------------------------- start mysql -------------------------------> "
docker load < $(pwd)/resources/mysql5.6.tar.gz
docker run -e MYSQL_ROOT_PASSWORD=123456 --restart=always -d --name mysql --net=host \
-e TZ="Asia/Shanghai" -v $(pwd)/data/mysql:/var/lib/mysql \
mysql:5.6  

echo " <---------------------------- start tomcat ------------------------------> "
docker load < $(pwd)/resources/tomcat7.tar.gz
docker run -p 80:8080 \
--restart=always -d --name tomcat \
-e TZ="Asia/Shanghai" -e JAVA_OPTS="-Xms512m -Xmx2048m" --log-driver=json-file --log-opt max-size=10m --log-opt max-file=5 \
-v $(pwd)/data/tomcat/webapps:/usr/local/tomcat/webapps/ -v $(pwd)/data/tomcat/tmp/work:/usr/local/tomcat/work/ -v $(pwd)/data/tomcat/tmp/temp:/usr/local/tomcat/temp/ -v $(pwd)/data/tomcat/tmp/root:/root -v $(pwd)/data/tomcat/logs:/usr/local/tomcat/logs \
tomcat:7
}
#execute script
main