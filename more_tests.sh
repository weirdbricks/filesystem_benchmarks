#!/bin/bash

yum -y -q install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
yum -y -q install Percona-Server-server-56

cd /tmp
curl -O --location https://github.com/brianfrankcooper/YCSB/releases/download/0.12.0/ycsb-0.12.0.tar.gz
tar xfvz ycsb-0.12.0.tar.gz
cd ycsb-0.12.0

# make sure mongo is not running
systemctl stop mongod

# get the volume id
volume=`find /dev/mapper/v* | head -n1`
# format the volume with ext4
filesystem=ext4
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
--number-int-cols=7 --auto-generate-sql --number-of-queries=2000 -v | tee /root/$filesystem-$benchmark.txt
echo "Stopping MySQL..."
systemctl stop mysqld
echo "preparing Mongo..."
mkdir -pv /media/mongo
chown -Rv mongod:mongod /media/mongo
sed -i "s#dbPath: /var/lib/mongo#dbPath: /media/mongo#" /etc/mongod.conf
benchmark=mongo
systemctl start mongod
mongo ycsb --eval "db.dropDatabase()"
cd /tmp/ycsb-0.12.0
./bin/ycsb load mongodb -s -P workloads/workloada -p recordcount=100000 -threads `nproc`
./bin/ycsb run mongodb-async -s -P workloads/workloada \
-p operationcount=100000 -threads `nproc` | egrep -i "runtime|throughput|return" | tee /root/$filesystem-$benchmark.txt


