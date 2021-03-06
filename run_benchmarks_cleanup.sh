#!/bin/bash

logfile="/var/log/filesystem_benchmarks_`date +"%Y_%m_%d_%H-%M"`.txt"
file="/etc/profile.d/jdk.sh"
if ! [ -f "$file" ];then
	echo "[  INFO  ] - Setting up the OpenJDK..."
        java=`find /usr/lib/jvm/ja*/j* -maxdepth 0 -type d`
        export JAVA_HOME=$java
        echo "JAVA_HOME=$java" >> $file
        export PATH=$PATH:$JAVA_HOME/bin/
        echo "PATH=$PATH:$JAVA_HOME/bin/" >> $file
else
	echo "[  OK  ] - OpenJDK setup correctly!"
fi

# function to check if a file exists
check_if_file_exists () {
        if [ ! -f $1 ]; then
                echo "The file $1 does not exist - exiting"
                exit 1
        fi
}

# run sanity checks before we start
check_if_file_exists /tmp/ycsb-0.12.0/bin/ycsb
check_if_file_exists /usr/sbin/mysqld
check_if_file_exists /usr/bin/mysqlslap
check_if_file_exists /usr/bin/fio
check_if_file_exists /usr/bin/mongod
check_if_file_exists /usr/sbin/mkfs.jfs
check_if_file_exists /usr/sbin/mkfs.xfs
check_if_file_exists /usr/sbin/iotop

echo "[ INFO ] - Using logfile $logfile."

function check-output()
{
	if [ $? != 0 ]; then
		printf "FAIL!!!!\n"
		exit 1
	fi
}

function mysql-test()
{
	benchmark=mysql
	# set the MySQL directories
	systemctl stop mysqld
	check-output
	mkdir -p /media/mysql
	check-output
	chown -R mysql:mysql /media/mysql
	check-output
	echo "Starting MySQL..."
	systemctl start mysqld &> $logfile
	check-output
	echo "Starting MySQL Slap..."
	time mysqlslap --concurrency=`nproc` --iterations=5 --number-char-cols=20 \
	--number-int-cols=7 --auto-generate-sql --number-of-queries=5000 -v > /root/$filesystem-$benchmark.txt
	check-output
	echo "Stopping MySQL..."
	systemctl stop mysqld &> $logfile
	check-output
}

function mongo-test()
{
        benchmark=mongo-ycsb
	systemctl stop mongod &> $logfile
	echo "preparing Mongo..."
	mkdir -p /media/mongo
	chown -R mongod:mongod /media/mongo
	systemctl start mongod &> $logfile
	sleep 3
	check-output
	mongo ycsb --eval "db.dropDatabase()" 2> $logfile
	check-output
	cd /tmp/ycsb-0.12.0
	./bin/ycsb load mongodb -s -P workloads/workloada -p recordcount=500000 -threads `nproc` 2> $logfile
	check-output
	./bin/ycsb run mongodb-async -s -P workloads/workloada \
	-p operationcount=500000 -threads `nproc` | egrep -i "runtime|throughput|return" 2> /root/$filesystem-$benchmark.txt
	systemctl stop mongod &> $logfile
	check-output
}

function fio-test()
{
	echo "Starting FIO test..."
	benchmark=fio
	fio --randrepeat=1 --ioengine=libaio --gtod_reduce=1 --name=test --bs=4k --iodepth=64 --size=2G --readwrite=randrw --rwmixread=75 --filename /media/fiotest | grep iops &> /root/$filesystem-$benchmark.txt
	check-output
}

# get the volume id
volume=`find /dev/mapper/v* | head -n1` &> $logfile

# make sure the volume isn't mounted to begin with
lsblk -l -o NAME,MOUNTPOINT $volume | grep media
if [ $? != 0 ]; then
        echo "[ INFO ] - OK, the volume is not mounted"
else
        echo "[ INFO  ] - The volume is mounted - unmounting .."
        cd /
	systemctl stop mysqld &> $logfile
	check-output
	systemctl stop mongod &> $logfile
	check-output
        umount /media
	check-output
fi

echo "---------------- Preparing EXT4 ----------------"
# format the volume with ext4
filesystem=ext4
mkfs.ext4 $volume -F &> $logfile
check-output
mount $volume /media &> $logfile
check-output
echo "[  OK  ] - EXT4 ready"

echo "---------------- Running EXT4 tests ----------------"
mysql-test
mongo-test
fio-test

echo "---------------- Preparing XFS tests ----------------"
cd /
umount /media
check-output
filesystem=xfs
mkfs.xfs $volume -f &> $logfile
check-output
mount $volume /media &> $logfile
check-output
echo "[  OK  ] - XFS ready"

echo "---------------- Running XFS tests ----------------"
mysql-test
mongo-test
fio-test

echo "---------------- Preparing JFS tests ----------------"
cd /
umount /media
check-output
filesystem=jfs
mkfs.jfs $volume -f &> $logfile
check-output
mount $volume /media &> $logfile
check-output
echo "[  OK  ] - JFS ready"

echo "---------------- Running JFS tests ----------------"
mysql-test
mongo-test
fio-test

echo "---------------- TESTS COMPLETE ----------------"
