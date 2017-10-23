#!/bin/bash

# a simple function to add packages using yum
function add-package()
{
rpm -qa | grep -i $1 &>/dev/null
if [ $? != 0 ]; then	
	echo "[ INFO ] - Package $1 is not installed. Installing..."
	yum install $1 -y -q
	if [ $? == 0 ]; then
	        echo "[  OK  ] - Package $1 is installed"
	else
		echo "[ FAIL ] - Something went wrong!"
	fi
else 
	echo "[  OK  ] - Package $1 is installed"
fi
}

add-package epel-release
add-package xfsprogs
add-package fio
add-package postgresql-contrib


df -hT /media
echo "--------------------pg_test_fsync--------------------"
pg_test_fsync -f /media/test -s 5
echo "--------------------FIO--------------------"
fio --randrepeat=1 --ioengine=libaio --gtod_reduce=1 --name=test --bs=4k --iodepth=64 --size=1G --readwrite=randrw --rwmixread=75 --filename /media/fiotest | grep iops
