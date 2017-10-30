#!/bin/bash

yum -y -q install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
yum -y -q install Percona-Server-server-56

# get the volume id
volume=`find /dev/mapper/v* | head -n1`
# format the volume with ext4
mkfs.ext4 $volume -F
# mount the volume
mount $volume /media -v

# set the MySQL directories
systemctl stop mysqld
mkdir -pv /media/mysql
sed -i "s#datadir=/var/lib/mysql#datadir=/media/mysql#" /etc/my.cnf
chown -Rv mysql:mysql /media/mysql
echo "Starting MySQL..."
systemctl start mysqld
