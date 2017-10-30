#!/bin/bash

function mysql-test()
{
	benchmark=mysql
	# set the MySQL directories
	systemctl stop mysqld
	mkdir -pv /media/mysql
	sed -i "s#datadir=/var/lib/mysql#datadir=/media/mysql#" /etc/my.cnf
	chown -Rv mysql:mysql /media/mysql
	echo "Starting MySQL..."
	systemctl start mysqld
	echo "Starting MySQL Slap..."
	time mysqlslap --concurrency=50 --iterations=10 --number-char-cols=20 \
	--number-int-cols=7 --auto-generate-sql --number-of-queries=2000 -v | tee /root/$filesystem-$benchmark.txt
	echo "Stopping MySQL..."
	systemctl stop mysqld
}

function mongo-test()
{
        benchmark=mongo
	systemctl stop mongod
	echo "preparing Mongo..."
	mkdir -pv /media/mongo
	chown -Rv mongod:mongod /media/mongo
	benchmark=mongo
	systemctl start mongod
	mongo ycsb --eval "db.dropDatabase()"
	cd /tmp/ycsb-0.12.0
	./bin/ycsb load mongodb -s -P workloads/workloada -p recordcount=100000 -threads `nproc`
	./bin/ycsb run mongodb-async -s -P workloads/workloada \
	-p operationcount=100000 -threads `nproc` | egrep -i "runtime|throughput|return" | tee /root/$filesystem-$benchmark.txt
	systemctl stop mongod

}


yum -y -q install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
yum -y -q install Percona-Server-server-56

sed -i "s#datadir=/var/lib/mysql#datadir=/media/mysql#" /etc/my.cnf
sed -i "s#dbPath: /var/lib/mongo#dbPath: /media/mongo#" /etc/mongod.conf


file="/tmp/ycsb-0.12.0/bin/ycsb"
if ! [ -f "$file" ];then
	echo "one-off setup of YCSB..."
	cd /tmp
	curl -O --location https://github.com/brianfrankcooper/YCSB/releases/download/0.12.0/ycsb-0.12.0.tar.gz
	tar xfvz ycsb-0.12.0.tar.gz
	cd ycsb-0.12.0
else
	echo "YCSB already installed :)"
fi

# get the volume id
volume=`find /dev/mapper/v* | head -n1`
echo "---------------- Preparing EXT4 ----------------"
# format the volume with ext4
filesystem=ext4
mkfs.ext4 $volume -F
# mount the volume
mount $volume /media -v
echo "---------------- Running EXT4 tests ----------------"
#mysql-test
#mongo-test
echo "---------------- Preparing XFS tests ----------------"
cd /
umount /media
filesystem=xfs
mkfs.xfs $volume -f
mount $volume /media -v
echo "---------------- Running XFS tests ----------------"
#mysql-test
#mongo-test
echo "---------------- Preparing JFS tests (journal on same volume) ----------------"
cd /
umount /media
filesystem=jfs
mkfs.jfs $volume -f
mount $volume /media -v
echo "---------------- Running JFS tests (journal on same volume) ----------------"
#mysql-test
#mongo-test
echo "---------------- Preparing JFS tests (journal on separate volume) ----------------"
volume2=`find /dev/mapper/v* | tail -n1`
cd /
umount /media
filesystem=jfs-separate
mkfs.jfs -j $volume $volume2 -f
mount $volume /media -v
echo "---------------- Running JFS tests (journal on separate volume) ----------------"
mysql-test
mongo-test
