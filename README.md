                           Squasher Readme
                           ===============
                           

Introduction
------------

Squasher is a script that help with setting up Ubuntu installation with a squashfs /usr. On first run, it will detect if AppArmor is set up, and asked you if you want to disable it. That is because AppArmor is not compatible with this setup. Then it will ask you if you want to set up a squashed /usr. What does this actually mean, is that it will compress the /usr using mksquashfs, set it to mount at /var/squashed/ro and set aufs to mount at /usr with read only branch at /var/squashed/ro and read write branch at /var/squashed/rw. When you restart, you should see some reduced application load time. This is because your /usr has been compressed into a squashfs image which is usually about one third the size of uncompressed directory. That means the hard disk will only need to get one third of data it normally need, thus reducing load times. Any write to /usr (that means when you install something) will be written to /var/squashed/rw uncompressed. Therefore new application will not receive the speedups. To overcome this, run this script again, it will detect your installation and prompt you to continue updating squashfs. After that, it will rename the old squashfs image to .usr.sqfs.old and the old aufs read write directory to /var/squashed/rw.old. You WILL need to remove both of these file before updating again. Otherwise things can break.


Usage 
-----
WARNING This script assume that you did not do any aufs setting in fstab. If you did, you have to manually squash you system.

For first time usage
1. Please install squashfs-tools and aufs-tools first.
2. Restart your system to single user mode. In Ubuntu, this means booting to recovery mode and select "drop to root command prompt"
3. Navigate to where you copy this script and run it like this './squasher.sh'
4. If it says access denied, run 'mount -o remount,rw /'. then 'chmod +x squasher.sh'
5. Run it, and it will prompt for AppArmor. If you choose to leave it, some stuff like wifi may not work when you restart.
5. Continue and then it will prompt you to squash your /usr. This is just a confirmation because after this, it will start the process. 
6. After it finish, restart your system by pressing Control-Alt-Del

For second and next time usage
1. Run it and if all goes well, it will prompt you with some parameter. Make sure the parameter is correct. This should be correct unless you do something to fstab.
2. Continue and it will recompress /usr.
3. Restart your system.
4. After you make sure everything is correct, your new application is still available, delete the old squashfs image and read write aufs branch by using the command "sudo rm /.usr.sqfs.old" and "sudo rm -rf /var/squashed/rm.old/"

AppArmor stuff
--------------
Even after AppArmor is deactivated, for some reason, the cupsd profile keep starting up. You can work around it temporarily by using the command 'sudo invoke-rc.d apparmor teardown'. But for parmenant result, consider purging AppArmor.