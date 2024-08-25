#!/bin/bash

# Jenkins 설치를 위한 변수 정의
JENKINS_REPO_URL="https://pkg.jenkins.io/redhat-stable/jenkins.repo"
JENKINS_REPO_KEY_URL="https://pkg.jenkins.io/redhat-stable/jenkins.io.key"
JENKINS_HOME="/var/lib/jenkins"
JENKINS_CAAS_HOME="/etc/sysconfig/jenkins/casc_configs"
JENKINS_LOG_HOME="/var/log/jenkins"
EFS_NAME="AWS_EFS_NAME"
ORG_NAME="ENV_ORG_NAME"
TEMA_NAME="ENV_TEAM_NAME"

# 시스템 업데이트 및 필수 패키지 설치
dnf update -y && dnf install -y java-17-amazon-corretto-devel wget git

# Jenkins 저장소 추가
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo && rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Jenkins 설치
dnf install -y --nogpgcheck jenkins-2.462.1-1.1

#efs util 설치
yum install -y amazon-efs-utils

# Jenkins 서비스를 시스템 시작 시 자동으로 시작하도록 설정
mkdir -p $JENKINS_HOME
chown jenkins:jenkins $JENKINS_HOME

mkdir -p $JENKINS_LOG_HOME
chown jenkins:jenkins $JENKINS_LOG_HOME 
echo "Log directory $JENKINS_LOG_HOME created."

mkdir -p $JENKINS_CAAS_HOME
chown jenkins:jenkins $JENKINS_CAAS_HOME
chmod 0755 $JENKINS_CAAS_HOME
echo "CaaS config directory $JENKINS_CAAS_HOME created."

git clone https://github.com/DevopsArtFactory/jenkins-deploy-script

cp jenkins-deploy-script/jenkins.yaml $JENKINS_CAAS_HOME/jenkins.yaml
cp jenkins-deploy-script/install-plugin.sh $JENKINS_HOME/install-plugin.sh
cp jenkins-deploy-script/jenkins_support.sh /usr/local/bin/jenkins-support
cp jenkins-deploy-script/plugins_default.txt $JENKINS_HOME/plugins_default.txt
cp jenkins-deploy-script/override.conf $JENKINS_CAAS_HOME/override.conf
cp jenkins-deploy-script/systemd.service /usr/lib/systemd/system/jenkins.service

FILE_SYSTEM_ID=$(aws efs describe-file-systems --query "FileSystems[?Name=='$EFS_NAME'].FileSystemId" --output text)

DNS_ADDRESSES=$(aws efs describe-file-systems --file-system-id "$FILE_SYSTEM_ID" --query "FileSystems[*].[FileSystemId]" --output text | awk '{print $1".efs.ap-northeast-2.amazonaws.com"}')

mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $DNS_ADDRESSES:/ $JENKINS_HOME/jobs

chmod +x $JENKINS_HOME/install-plugin.sh
chmod +x /usr/local/bin/jenkins-support

$JENKINS_HOME/install-plugin.sh < $JENKINS_HOME/plugins_default.txt

chown -R jenkins:jenkins $JENKINS_CAAS_HOME
chown -R jenkins:jenkins $JENKINS_HOME

JENKINS_CLIENT_ID=$(aws ssm get-parameter --name "jenkins_client_id" --with-decryption --query "Parameter.Value" --output text)
JENKINS_CLIENT_SECRET=$(aws ssm get-parameter --name "jenkins_client_secret" --with-decryption --query "Parameter.Value" --output text)

sed -i "s/jenkins_client_id/$JENKINS_CLIENT_ID/g" $JENKINS_CAAS_HOME/jenkins.yaml
sed -i "s/jenkins_client_secret/$JENKINS_CLIENT_SECRET/g" $JENKINS_CAAS_HOME/jenkins.yaml
sed -i "s/ORG_NAME/$ENV_ORG_NAME/g" $JENKINS_CAAS_HOME/jenkins.yaml
sed -i "s/TEAM_NAME/$ENV_TEAM_NAME/g" $JENKINS_CAAS_HOME/jenkins.yaml

sudo systemctl enable jenkins

# Jenkins 서비스 시작
sudo systemctl start jenkins

echo "Jenkins 설치가 완료되었습니다."
