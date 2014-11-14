FROM centos:centos7
MAINTAINER Chris Collins <collins.christopher@gmail.com>


RUN echo -e "\
[EPEL]\n\
name=Extra Packages for Enterprise Linux \$releasever - \$basearch\n\
#baseurl=http://download.fedoraproject.org/pub/epel/\$releasever/\$basearch\n\
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-\$releasever&arch=\$basearch\n\
failovermethod=priority\n\
enabled=1\n\
gpgcheck=0\n\
" >> /etc/yum.repos.d/epel.repo

RUN yum install -y pwgen mariadb-server && yum clean all
ADD setup-mysql.sh /setup-mysql.sh 

ENTRYPOINT ["/setup-mysql.sh"]
