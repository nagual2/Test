#!/bin/sh

VERSION="test_fs_memdisk_bsd.sh v0.02"

# Создаем диск в памяти на 6 гиг (всего 8) итого системе остаётся 2 гига.
DISKDEV="md0"
DISKSIZE="7G"
TESTSIZE="-s 6600m:128k -r 800m"
TEST2SIZE="bs=1M count=6600"
LOGFILE="test_fs_memdisk_bsd.log"
exec 1>$LOGFILE 2>&1
/bin/echo $VERSION
/bin/echo

start_md ()
{
/bin/echo "Starting memdisk "
/sbin/mdconfig -a -t malloc -s $DISKSIZE # malloc swap
/bin/mkdir -p /mnt/fs
/bin/chmod 777 /mnt/fs
/bin/echo
}

new_fs_ufs ()
{
/bin/echo "Starting newfs UFS $UFS "
/sbin/newfs $UFS /dev/$DISKDEV
/sbin/tunefs -p /dev/$DISKDEV
/sbin/mount /dev/$DISKDEV /mnt/fs
/bin/df -H |grep $DISKDEV
/bin/echo
}

stop_fs_ufs ()
{
/bin/echo "Stoping UFS $UFS "
/sbin/umount -f /mnt/fs
/bin/echo
}

new_fs_gjournal ()
{
/bin/echo "Starting newfs gjournal "
/sbin/gjournal label $DISKDEV # -s 400m  ?
/sbin/newfs -O2 -J /dev/$DISKDEV.journal
/sbin/tunefs -p /dev/$DISKDEV
/sbin/gjournal list
/sbin/gjournal status -s
/sbin/mount -o async /dev/$DISKDEV.journal /mnt/fs
/bin/df -H
/bin/echo
}

stop_fs_gjournal ()
{
/bin/echo "Stoping fs gjournal "
/sbin/umount -f /mnt/fs
/sbin/gjournal stop $DISKDEV
/bin/echo
}

new_fs_zfs ()
{
/bin/echo "Starting newfs ZFS "
/sbin/zpool create mdpool /dev/$DISKDEV
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set mountpoint=/mnt/fs mdpool
/bin/df -H |grep mdpool
/bin/echo
}

new_fs_zfs_checksumoff ()
{
/bin/echo "Starting newfs ZFS checksum=off "
/sbin/zpool create mdpool /dev/$DISKDEV
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set checksum=off mdpool
/sbin/zfs set mountpoint=/mnt/fs mdpool
/bin/df -H |grep mdpool
/bin/echo
}

stop_fs_zfs ()
{
/bin/echo "Stoping fs ZFS "
/sbin/umount -f /mnt/fs
/sbin/zpool destroy mdpool
/bin/echo
}

test_bonnie ()
{
/bin/echo "Starting test bonnie  $TESTSIZE $TESTNAME"
/bin/date
/usr/local/sbin/bonnie++ -d /mnt/fs -u root $TESTSIZE $TESTNAME
/bin/date
/bin/echo
}

test_dd ()
{
/bin/echo "Starting test dd $TEST2SIZE "
/bin/date
/bin/dd if=/dev/zero of=/mnt/fs/test $TEST2SIZE
/bin/date
/bin/dd if=/mnt/fs/test of=/dev/null $TEST2SIZE
/bin/date
/bin/dd if=/dev/random of=/mnt/fs/test $TEST2SIZE
/bin/date
/bin/dd if=/mnt/fs/test of=/dev/null $TEST2SIZE
/bin/date
/bin/rm /mnt/fs/test
/bin/date
/bin/echo
}

stop_md ()
{
# Выключаем все
/bin/echo "Shutting memdisk "
/sbin/mdconfig -d -u /dev/$DISKDEV
/bin/rm -R /mnt/fs
/bin/echo
}

# Тестируем ;-)

start_md

UFS="-O2"
new_fs_ufs
TESTNAME="-m UFS-O2"
test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U"
new_fs_ufs
TESTNAME="-m UFS-O2-U"
test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U -j"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j"
test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U -j -t"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j-t"
test_bonnie
#test_dd
stop_fs_ufs

#new_fs_gjournal
TESTNAME="-m UFS-gjournal"
#test_bonnie
#test_dd
#exit 0
#stop_fs_gjournal

sysctl vfs.zfs.prefetch_disable=0

new_fs_zfs
TESTNAME="-m ZFS"
test_bonnie
#test_dd
stop_fs_zfs

# ZFS с checksum=off.
new_fs_zfs_checksumoff
TESTNAME="-m ZFS_no_checksum"
test_bonnie
#test_dd
stop_fs_zfs

/sbin/sysctl vfs.zfs.prefetch_disable=1
/bin/echo "Disable ZFS prefetch "
/bin/echo

new_fs_zfs
TESTNAME="-m ZFS_no_prefetch"
test_bonnie
#test_dd
stop_fs_zfs

new_fs_zfs_checksumoff
TESTNAME="-m ZFS_no_checksum_&_no_prefetch"
test_bonnie
#test_dd
stop_fs_zfs

stop_md

exit 0





