FROM centos:centos7
MAINTAINER Chris Collins <collins.christopher@gmail.com>

ENV TERM xterm

RUN echo -e "\
[EPEL]\n\
name=Extra Packages for Enterprise Linux \$releasever - \$basearch\n\
#baseurl=http://download.fedoraproject.org/pub/epel/\$releasever/\$basearch\n\
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-\$releasever&arch=\$basearch\n\
failovermethod=priority\n\
enabled=1\n\
gpgcheck=0\n\
" >> /etc/yum.repos.d/epel.repo

RUN yum install -y pwgen hostname mariadb-server && yum clean all
ADD setup-mysql.sh /setup-mysql.sh 

ADD utf8.cnf /etc/my.cnf.d/utf8.cnf

ENTRYPOINT ["/setup-mysql.sh"]
