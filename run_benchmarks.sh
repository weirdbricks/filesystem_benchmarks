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
add-package pigz
add-package grub2-tools
add-package grub2-tools-minimal

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
	echo "[ INFO ] - GRUB submenu already disabled!"	
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
	echo "[ INFO ] - Kernel version set to \"3.10.0-514\""
fi

#add-package http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm

#df -hT /media
#echo "--------------------pg_test_fsync--------------------"
#pg_test_fsync -f /media/test -s 5
#echo "--------------------FIO--------------------"
#fio --randrepeat=1 --ioengine=libaio --gtod_reduce=1 --name=test --bs=4k --iodepth=64 --size=1G --readwrite=randrw --rwmixread=75 --filename /media/fiotest | grep iops
