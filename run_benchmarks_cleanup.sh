#!/bin/bash

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

function mysql-test()
{
	benchmark=mysql
	# set the MySQL directories
	systemctl stop mysqld
	mkdir -pv /media/mysql
	chown -Rv mysql:mysql /media/mysql
	echo "Starting MySQL..."
	systemctl start mysqld
	echo "Starting MySQL Slap..."
	time mysqlslap --concurrency=50 --iterations=10 --number-char-cols=20 \
	--number-int-cols=7 --auto-generate-sql --number-of-queries=2000 -v | tee /root/$filesystem-$benchmark.txt
	echo "Stopping MySQL..."
	systemctl stop mysqld
}

function mongo-tests()
{
        benchmark=mongo-ycsb
	systemctl stop mongod
	echo "preparing Mongo..."
	mkdir -pv /media/mongo
	chown -Rv mongod:mongod /media/mongo
	systemctl start mongod
	mongo ycsb --eval "db.dropDatabase()"
	cd /tmp/ycsb-0.12.0
	./bin/ycsb load mongodb -s -P workloads/workloada -p recordcount=100000 -threads `nproc`
	./bin/ycsb run mongodb-async -s -P workloads/workloada \
	-p operationcount=100000 -threads `nproc` | egrep -i "runtime|throughput|return" | tee /root/$filesystem-$benchmark.txt
	benchmark=mongo-perf
	cd /tmp/mongo-perf-r20171009
        time python benchrun.py -f testcases/simple_* -t `nproc` --trialTime 30 | tee /root/$filesystem-$benchmark.txt
	systemctl stop mongod
}

function fio-test()
{
	benchmark=fio
	fio --randrepeat=1 --ioengine=libaio --gtod_reduce=1 --name=test --bs=4k --iodepth=64 --size=2G --readwrite=randrw --rwmixread=75 --filename /media/fiotest | grep iops | tee /root/$filesystem-$benchmark.txt
}

function mongo-perf-test()
{
	cd /tmp/mongo-perf-r20171009
	time python benchrun.py -f testcases/simple_* -t `nproc` | tee /root/$filesystem-$benchmark.txt
}

# get the volume id
volume=`find /dev/mapper/v* | head -n1`

# make sure the volume isn't mounted to begin with
lsblk -l -o NAME,MOUNTPOINT $volume | grep media
if [ $? != 0 ]; then
        echo "[ INFO ] - OK, the volume is not mounted"
else
        echo "[ INFO  ] - The volume is mounted - unmounting .."
        cd /
        umount /media
fi

echo "---------------- Preparing EXT4 ----------------"
# format the volume with ext4
filesystem=ext4
mkfs.ext4 $volume -F

# mount the volume with ext4
mount $volume /media -v

echo "---------------- Running EXT4 tests ----------------"
mysql-test
mongo-tests
fio-test
echo "bogooooooooon"
exit 1

echo "---------------- Preparing XFS tests ----------------"
cd /
umount /media
filesystem=xfs
mkfs.xfs $volume -f
mount $volume /media -v

echo "---------------- Running XFS tests ----------------"
#mysql-test
#mongo-test

echo "---------------- Preparing JFS tests ----------------"
cd /
umount /media
filesystem=jfs
mkfs.jfs $volume -f
mount $volume /media -v

echo "---------------- Running JFS tests ----------------"
#mysql-test
#mongo-test
