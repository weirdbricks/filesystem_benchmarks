#!/bin/bash

yum -y -q install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
yum -y -q install Percona-Server-server-56

# make sure mongo is not running
systemctl stop mongod

# get the volume id
volume=`find /dev/mapper/v* | head -n1`
# format the volume with ext4
fs=ext4
mkfs.ext4 $volume -F
# mount the volume
mount $volume /media -v
benchmark=mysql
# set the MySQL directories
systemctl stop mysqld
mkdir -pv /media/mysql
sed -i "s#datadir=/var/lib/mysql#datadir=/media/mysql#" /etc/my.cnf
chown -Rv mysql:mysql /media/mysql
echo "Starting MySQL..."
systemctl start mysqld
time mysqlslap --concurrency=50 --iterations=10 --number-char-cols=20 \
--number-int-cols=7 --auto-generate-sql --number-of-queries=2000 -v | tee /root/$fs-$benchmark.txt
echo "Stopping MySQL..."
systemctl stop mysqld
echo "preparing Mongo..."
mkdir -pv /media/mongo
chown -Rv mongod:mongod /media/mongo
sed -i "s#dbPath: /var/lib/mongo#dbPath: /media/mongo#" /etc/mongod.conf
benchmark=mongo
systemctl start mongod

