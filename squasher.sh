#! /bin/bash

#    Copyright 2012 Muhd Amirul Ashraf <asdacap@gmail.com>
#
#    This script is called Squasher
#
#    Squasher is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Squasher is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Squasher.  If not, see <http://www.gnu.org/licenses/>.


#check if usr is empty. If it is, then we need to mount -a first
output=`ls /usr`
if [ "$output" == "" ]
then
	mount -o remount,rw /
	mount -a
	if [ $? != 0 ];then
		echo "Error mounting /usr"
		exit
	fi
	#for some reason, aufs will not mount. So we have to manually mount it.
	fstabstr=`cat /etc/fstab`
	parser="aufs\s+/usr\s+aufs\s+([^[:space:]]+)"
	if ! [[ $fstabstr =~ $parser ]]
	then
		echo "For some reason... your /usr is empty but there is no aufs definition in fstab."
		echo "Did this script mess things up before?"
		echo "Because if it did, you probably need to reinstall ubuntu."
		exit
	fi
	aufsline="${BASH_REMATCH[1]}"
	parser="br:([^ ,=:]+)=rw:([^ ,=:]+)=ro"
	if ! [[ $aufsline =~ $parser ]]
	then
		echo "Error: Fail to parse aufs ro and rw parameter. Sorry, my bad."
		exit
	fi
	targetrw="${BASH_REMATCH[1]}"
	targetro="${BASH_REMATCH[2]}"
	mount -t aufs -o br:${targetrw}=rw:${targetro}=ro none /usr
fi

output=`whoami`

#superuser check

if [ $? != 0 ]
then
	echo "Something weird happened.. sorry"
	exit
fi

if [ "$output" != "root" ]
then
	echo "You need to be root first. Please start this script using superuser access"
	exit
fi

#check squashfs-tools and aufs

dpkg -s squashfs-tools > /dev/null 2> /dev/null
squashfsinstalled=$? 
dpkg -s aufs-tools > /dev/null 2> /dev/null
aufsinstalled=$?

if [[  $squashfsinstalled != 0 || $aufsinstalled != 0  ]]
then
	echo "For some reased squashfs-tools and aufs-tools is not installed. Please install it first."
	echo "You can install it by using the command sudo apt-get install squashfs-tools aufs-tools."
	exit
fi

#single user mode check
output=`runlevel`
status=$?

if [[ "$output" != "N 1\n" && $status == 0 ]]
then
	echo -e "Please run this in single user mode (runlevel 1). \nThat means, restart ubuntu in recovery mode, and choose to go to root terminal, \nThen you run this script. "
	exit
fi

#it should crash in single user mode
if [ $status != 1 ]
then
	echo "An unknown error occured. Sorry"
	exit
fi

#warning message
echo "Warning! Make sure you make a backup of your /usr unless you dont mind reinstalling everything."
echo "I am not liable for any damage caused by this script"

mount -o remount,rw /
[ $? != 0 ] && echo "An error occured trying to remount root." && exit

#check apparmor status

exist=0
for filename in `ls /etc/rcS.d`
do
	if [[ $filename =~ apparmor$ ]]
	then
		exist=1
	fi
done

if [ $exist == 1 ]
then
	echo -e "Warning! AppArmor is enabled. \n AppArmor can cause some things like wifi or printers to not work when using squashed in /usr."
	echo "Disable AppArmor ? "
	select yn in "Yes" "No";do
		case $yn in
			Yes )
				invoke-rc.d apparmor stop
				update-rc.d -f apparmor remove
				echo -e "Disabled AppArmor service and automatic startup.\n Unfortunately for some reason, /usr/sbin/cupsd profile may still be enforced. \n Which means printers may still not work. \nYou may need to fully purge Apparmor for it to work"
				break ;;
			No ) break ;;
		esac
	done
fi

targetsquashplace="/var/squashed"
targetro=$targetsquashplace"/ro"
targetrw=$targetsquashplace"/rw"

tempplace="/.usr.sqfs.tmp"
targetsquash="/.usr.sqfs"

backedupusr="/usr.backup"

echo "Checking aufs setting on fstab..."

fsabstr=`cat /etc/fstab`
parser="aufs\s+/usr\s+aufs\s+([^[:space:]]+)"

if ! [[ $fstabstr =~ $parser ]]
then
	echo "aufs on /usr is not installed"
	echo "Squash your /usr? (Warning! After this, there is no turning back automatically.)"
	select yn in "Yes" "No";do
		case $yn in
			Yes )
				break ;;
			No ) 
				exit
				break ;;
		esac
	done
	mksquashfs /usr $targetsquash
	[ $? != 0 ] && echo "error squashing $targetsquash. abort." && exit
	mkdir $targetsquashplace
	mkdir $targetro
	mkdir $targetrw
	echo -e "Renaming /usr to $backedupusr for backup purpose. \nDelete it later if you are certain everything worked."
	mv /usr $backedupusr
	mkdir /usr
	echo "Setting up fstab..."
	echo -e "\n\n#The following two line is used to mount squashed /usr" >> /etc/fstab
	echo -e "\n$targetsquash	$targetro	squashfs	loop,ro 0 0" >> /etc/fstab
	echo -e "\naufs	/usr	aufs	br:${targetrw}=rw:${targetro}=ro	0 0" >> /etc/fstab
	echo "Everything should be fine... Now remounting..."
	mount -a
	if [ $? != 0 ]
	then
		echo "Mounting does not work... Sorry, you have to manually fix things"
		exit
	fi
	echo "The new /usr should now be online. But to be sure, restart your system."
else
	echo "aufs on /usr is detected"
	aufsline="${BASH_REMATCH[1]}"
	parser="br:([^ ,=:]+)=rw:([^ ,=:]+)=ro"
	if ! [[ $aufsline =~ $parser ]]
	then
		echo "Error: Fail to parse aufs ro and rw parameter. Sorry, my bad."
		exit
	fi
	targetrw="${BASH_REMATCH[1]}"
	targetro="${BASH_REMATCH[2]}"
	echo "Target rw is : $targetrw"
	echo "Target ro is : $targetro"
	parser="([^ ,=:[:space:]]+)\s+([^ ,=:[:space:]]+)\s+squashfs\s+loop,ro"
	if ! [[ $fstabstr =~ $parser ]]
	then
		echo "Error: Fail to parse squashfs parameter. Sorry, my bad."
		exit
	fi
	targetsquash="${BASH_REMATCH[1]}"
	echo "Squashfs image is : ${targetsquash}"
	echo "Make sure the above parameter is correct. Continue ? "
	select yn in "Yes" "No";do
		case $yn in
			Yes )
				break ;;
			No ) 
				exit
				break ;;
		esac
	done
	echo "Resquashing to new squashfs image ..."
	mksquashfs /usr ${targetsquash}.tmp
	[[ $? != 0 ]] && echo "Error squashing" && exit;
	echo "Squashing complete. Unmounting filesystem..."
	umount /usr
	umount $targetro
	echo "Replacing file..."
	mv $targetsquash ${targetsquash}.old
	mv ${targetsquash}.tmp $targetsquash
	mv $targetrw ${targetrw}.old
	mkdir $targetrw
	echo "The old squashfs has been renamed to ${targetsquash}.old"
	echo "The old targetrw has been renamed to ${targetrw}.old"
	echo "Please delete them later if everything is ok."
	echo "Remounting..."
	[[ $? != 0 ]] && echo "Error remounting. Something went wrong." && exit
	echo "New /usr should now be online. But for sure, restart your system and hope for the best."
fi














