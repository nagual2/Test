#!/bin/sh

# Создаем диск в памяти на 6 гиг (всего 8) итого системе остаётся 2гига.
DISKDEV="md0"
DISKSIZE="6G"
TESTSIZE="-s 5700m:128k -r 1800m"
TEST2SIZE="bs=1M count=5400"
UFS="-O2"
TOLOG="2>>&./test_01_memdisk_bsd.sh"

start_md ()
{
/bin/echo "Starting memdisk "
/sbin/mdconfig -a -t swap -s $DISKSIZE # malloc
/bin/mkdir -p /mnt/$DISKDEV
/bin/chmod 777 /mnt/$DISKDEV
/bin/echo
}

new_fs_ufs ()
{
/bin/echo "Starting newfs $UFS "
/sbin/newfs $UFS /dev/$DISKDEV
/sbin/tunefs -p /dev/$DISKDEV
/sbin/mount /dev/$DISKDEV /mnt/$DISKDEV
/bin/df -H |grep $DISKDEV
/bin/echo
}

stop_fs_ufs ()
{
/bin/echo "Stoping $UFS "
/sbin/umount -f /mnt/$DISKDEV
/bin/echo
}

#new_fs_gjournal ()
#{
#/bin/echo "Starting newfs gjournal "
#/sbin/gjournal label $DISKDEV
#/sbin/newfs -O2 -J /dev/$DISKDEV.journal
#/sbin/tunefs -p /dev/$DISKDEV
#/sbin/gjournal list
#/sbin/gjournal status -s
#/sbin/mount -o async /dev/$DISKDEV.journal /mnt/$DISKDEV
#/bin/df -H
#/bin/echo
#}

#stop_fs_gjournal ()
#{
#/bin/echo "Stoping fs gjournal "
#/sbin/umount -f /mnt/$DISKDEV
#/sbin/gjournal stop $DISKDEV
#/bin/echo
#}

new_fs_zfs ()
{
/bin/echo "Starting newfs ZFS "
/sbin/zpool create mdpool /dev/$DISKDEV
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set mountpoint=/mnt/$DISKDEV mdpool
#/sbin/zfs get mountpoint mdpool
#/sbin/mount -t zfs mdpool /mnt/$DISKDEV
/bin/df -H |grep $DISKDEV
/bin/echo
}

new_fs_zfs_checksumoff ()
{
/bin/echo "Starting newfs ZFS checksum=off "
/sbin/zpool create mdpool /dev/$DISKDEV
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set checksum=off mdpool
/sbin/zfs set mountpoint=/mnt/$DISKDEV mdpool
#/sbin/zfs get mountpoint mdpool
#/sbin/mount -t zfs mdpool /mnt/$DISKDEV
/bin/df -H |grep $DISKDEV
/bin/echo
}

stop_fs_zfs ()
{
/bin/echo "Stoping fs ZFS "
/sbin/umount -f /mnt/$DISKDEV
/sbin/zpool destroy mdpool
/bin/echo
#stop_md
}

test_bonnie ()
{
/bin/echo "Starting test bonnie  $TESTSIZE $TESTNAME"
/bin/date
/usr/local/sbin/bonnie++ -d /mnt/$DISKDEV -u root $TESTSIZE $TESTNAME
/bin/date
/bin/echo
}

test_dd ()
{
/bin/echo "Starting test dd $TEST2SIZE "
/bin/date
/bin/dd if=/dev/zero of=/mnt/$DISKDEV/test $TEST2SIZE
/bin/date
/bin/dd if=/mnt/$DISKDEV/test of=/dev/null $TEST2SIZE
/bin/date
/bin/dd if=/dev/random of=/mnt/$DISKDEV/test $TEST2SIZE
/bin/date
/bin/dd if=/mnt/$DISKDEV/test of=/dev/null $TEST2SIZE
/bin/date
/bin/rm /mnt/$DISKDEV/test
/bin/date
/bin/echo
}

stop_md ()
{
# Выключаем все
/bin/echo "Shutting memdisk "
/sbin/mdconfig -d -u /dev/$DISKDEV
/bin/rm -R /mnt/$DISKDEV
/bin/echo
}

# Тестируем ;-)

start_md

new_fs_ufs
TESTNAME="-m UFS"
test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U"
new_fs_ufs
TESTNAME="-m UFS-U"
test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U -j"
new_fs_ufs
TESTNAME="-m UFS-Uj"
test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U -j -t"
new_fs_ufs
TESTNAME="-m UFS-Ujt"
test_bonnie
#test_dd
stop_fs_ufs

#new_fs_gjournal
#TESTNAME="-m UFS-gjournal"
#test_bonnie
#test_dd
#exit 0
#stop_fs_gjournal

new_fs_zfs
TESTNAME="-m ZFS"
test_bonnie
#test_dd
stop_fs_zfs

# ZFS с checksum=off.
new_fs_zfs_checksumoff
TESTNAME="-m ZFS_checksumoff"
test_bonnie
#test_dd
stop_fs_zfs

stop_md

exit 0





