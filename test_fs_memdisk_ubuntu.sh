#!/bin/sh

VERSION="test_fs_memdisk_ubuntu.sh v0.02"

# Создаем диск в памяти на 7 гиг (всего 8) итого системе остаётся 1 гига.
# echo 'GRUB_CMDLINE_LINUX="ramdisk_size=7340032"' >/etc/default/grub
# update-grub
TESTSIZE="-s 6600m:128k -r 800m"
TEST2SIZE="bs=1M count=6600"
LOGFILE="test_fs_memdisk_ubuntu.log"
exec 1>$LOGFILE 2>&1
/bin/echo $VERSION
/bin/echo
/bin/mkdir -p /mnt/fs
/bin/echo "less /etc/mke2fs.conf"
/bin/less /etc/mke2fs.conf
/bin/echo

new_fs_ext4 ()
{
/bin/echo "Starting newfs ext4 "
/sbin/mkfs.ext4 /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/sbin/tune2fs -l /dev/ram0
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

new_fs_ext4_defrag ()
{
/bin/echo "Starting newfs ext4 defrag "
/sbin/mkfs.ext4 /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/sbin/tune2fs -l /dev/ram0
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
/bin/echo "Starting defrag "
./defrag.sh &
}

new_fs_ext3 ()
{
/bin/echo "Starting newfs ext3 "
/sbin/mkfs.ext3 /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/sbin/tune2fs -l /dev/ram0
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

new_fs_ext2 ()
{
/bin/echo "Starting newfs ext2 "
/sbin/mkfs.ext2 /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

new_fs_btrfs ()
{
/bin/echo "Starting newfs btrfs "
/sbin/mkfs.btrfs /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

new_fs_xfs ()
{
/bin/echo "Starting newfs xfs "
/sbin/mkfs.xfs -f /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

new_fs_jfs ()
{
/bin/echo "Starting newfs jfs "
/sbin/mkfs.jfs /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

new_fs_zfs ()
{
/bin/echo "Starting newfs ZFS "
/sbin/zpool create mdpool /dev/ram0
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set mountpoint=/mnt/fs mdpool
/bin/mount |grep mdpool
/bin/df -H |grep mdpool
/bin/echo
}

new_fs_zfs_checksumoff ()
{
/bin/echo "Starting newfs ZFS checksum=off "
/sbin/zpool create mdpool /dev/ram0
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set checksum=off mdpool
/sbin/zfs set mountpoint=/mnt/fs mdpool
/bin/mount |grep mdpool
/bin/df -H |grep mdpool
/bin/echo
}

new_fs_reiserfs ()
{
/bin/echo "Starting newfs reiserfs "
/sbin/mkfs.reiserfs /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

stop_fs_ext4 ()
{
/bin/echo "Stoping newfs ext4 "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_ext4_defrag ()
{
/bin/echo "Stoping defrag "
pids=`ps axw |grep "/bin/sh ./defrag.sh" | grep -v grep | awk '{print ($1)}'`
if [ "x$pids" != "x" ] ; then
    echo "kill $pids"
    /bin/kill -9 $pids
fi
/bin/sleep 5
/bin/echo "Stoping newfs ext4 "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_ext3 ()
{
/bin/echo "Stoping newfs ext3 "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_ext2 ()
{
/bin/echo "Stoping newfs ext2 "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_btrfs ()
{
/bin/echo "Stoping newfs btrfs "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_xfs ()
{
/bin/echo "Stoping newfs xfs "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_jfs ()
{
/bin/echo "Stoping newfs jfs "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_reiserfs ()
{
/bin/echo "Stoping newfs jfs "
/bin/umount -f /mnt/fs
/bin/echo
}

stop_fs_zfs ()
{
/bin/echo "Stoping newfs zfs "
/bin/umount -f /mnt/fs
/bin/sleep 5
/sbin/zpool destroy mdpool
/bin/echo
}

stop_fs_zfs_checksumoff ()
{
/bin/echo "Stoping newfs zfs checksum=off "
/bin/umount -f /mnt/fs
/bin/sleep 5
/sbin/zpool destroy mdpool
/bin/echo
}

test_bonnie ()
{
/bin/echo "Starting test bonnie  $TESTSIZE $TESTNAME"
/bin/date
/usr/sbin/bonnie++ -d /mnt/fs -u root $TESTSIZE $TESTNAME
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

#start

new_fs_ext4
TESTNAME="-m ext4"
test_bonnie
#test_dd
stop_fs_ext4

new_fs_ext4_defrag
TESTNAME="-m ext4_defrag"
test_bonnie
#test_dd
stop_fs_ext4_defrag

new_fs_ext3
TESTNAME="-m ext3"
test_bonnie
#test_dd
stop_fs_ext3

new_fs_ext2
TESTNAME="-m ext2"
test_bonnie
#test_dd
stop_fs_ext2

new_fs_xfs
TESTNAME="-m xfs"
test_bonnie
#test_dd
stop_fs_xfs

new_fs_jfs
TESTNAME="-m jfs"
test_bonnie
#test_dd
stop_fs_jfs

new_fs_reiserfs
TESTNAME="-m reiserfs"
test_bonnie
#test_dd
stop_fs_reiserfs

new_fs_zfs
TESTNAME="-m zfs"
test_bonnie
#test_dd
stop_fs_zfs

new_fs_zfs_checksumoff
TESTNAME="-m zfs_checksum_off"
test_bonnie
#test_dd
stop_fs_zfs_checksumoff

new_fs_btrfs
TESTNAME="-m btrfs"
test_bonnie
#test_dd
stop_fs_btrfs

#stop
exit 0


















