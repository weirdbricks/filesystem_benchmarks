#!/bin/bash

# a simple function to add packages using yum
function add-package()
{
if [ -z $2 ]; then
  rpm -qa | grep -i $1 &>/dev/null
else
  rpm -qa | grep -i $2 &>/dev/null
fi
if [ $? != 0 ]; then	
	echo "[ INFO ] - Package $1 is not installed. Installing..."
	yum install $1 -y -q
	if [ $? == 0 ]; then
	        echo "[  OK  ] - Package $1 is installed"
	else
		echo "[ FAIL ] - Something went wrong!"
		exit 1
	fi
else 
	echo "[  OK  ] - Package $1 is installed"
fi
}

file="/etc/yum.repos.d/mongodb-org-3.4.repo"
if ! [ -f "$file" ];then
	echo "[ INFO ] - The file $file was not found. Adding..."
printf '[mongodb-org-3.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc\n' > $file
        if [ $? != 0 ]; then
                echo "[ FAIL ] - Something went wrong!"
	else
		echo "[  OK  ] - The file $file was added!"
        fi
else
	echo "[  OK  ] - The file $file is in position!"
fi

add-package epel-release
add-package xfsprogs
add-package fio
add-package postgresql-contrib
add-package pigz
add-package grub2-tools
add-package grub2-tools-minimal
add-package java-1.8.0-openjdk 
add-package mongodb-org

file="/etc/profile.d/jdk.sh"
if ! [ -f "$file" ];then
	echo "[  INFO  ] - Setting up the OpenJDK..."
        java=`find /usr/lib/jvm/ja*/j* -maxdepth 0 -type d`
        export JAVA_HOME=/usr/lib/jvm$java
        echo "JAVA_HOME=/usr/lib/jvm$java" >> $file
        export PATH=$PATH:$JAVA_HOME/bin/
        echo "PATH=$PATH:$JAVA_HOME/bin/" >> $file
else
	echo "[  OK  ] - OpenJDK setup correctly!"
fi

grep GRUB_DISABLE_SUBMENU /etc/default/grub &>/dev/null 
if [ $? != 0 ]; then
	echo "[ INFO ] - Disabling GRUB submenu..."
	echo "GRUB_DISABLE_SUBMENU=y" >> /etc/default/grub
	if [ $? == 0 ]; then
                echo "[  OK  ] - GRUB submenu disabled!"
        else
                echo "[ FAIL ] - Something went wrong!"
		exit 1
        fi
else
	echo "[  OK  ] - GRUB submenu already disabled!"	
fi

grub2-mkconfig -o /boot/grub/grub.cfg &>/dev/null

# check the kernel version
uname -r|grep "3.10.0-514" &>/dev/null
if [ $? != 0 ]; then
	echo "[ INFO ] - Kernel version not set to \"3.10.0-514\""
        changeto=`awk -F\' '$1=="menuentry " {print i++ " : " $2}' /boot/grub/grub.cfg | grep 3.10.0-514 | grep -v "recovery" | awk '{print $1}'`
	echo $changeto
	if [ -z "${changeto}" ]; then
		echo "[ FAIL ] - Something went wrong!"
		exit 1
	fi
	grub2-set-default $changeto
	echo "[ INFO ] - Rebooting system in 5 seconds..."
	sleep 5
	reboot now
else
	echo "[  OK  ] - Kernel version set to \"3.10.0-514\""
fi

add-package http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm elrepo
add-package kmod-jfs

# check if jfs is already loaded
lsmod | grep jfs &>/dev/null
if [ $? != 0 ]; then
	modprobe jfs
	if [ $? != 0 ]; then
		echo "[ FAIL ] - Something went wrong!"
	else
		echo "[  OK  ] - The JFS module is already loaded!"
	fi
else
	echo "[  OK  ] - The JFS module is already loaded!"	
fi	


#df -hT /media
#echo "--------------------pg_test_fsync--------------------"
#pg_test_fsync -f /media/test -s 5
#echo "--------------------FIO--------------------"
#fio --randrepeat=1 --ioengine=libaio --gtod_reduce=1 --name=test --bs=4k --iodepth=64 --size=1G --readwrite=randrw --rwmixread=75 --filename /media/fiotest | grep iops
