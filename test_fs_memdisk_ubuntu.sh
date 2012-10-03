#!/bin/sh

# Создаем диск в памяти на 6 гиг (всего 8) итого системе остаётся 2гига.
# echo 'GRUB_CMDLINE_LINUX="ramdisk_size=6291456"' >/etc/default/grub
TESTSIZE="-s 5700m:128k -r 1800m"
TEST2SIZE="bs=1M count=5400"
TOLOG="2>>&./test_01_memdisk_bsd.sh"

new_fs_ext4 ()
{
/bin/echo "Starting newfs ext4 "
/sbin/mkfs.ext4 /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
/bin/mount |grep ram
/bin/df -H |grep ram
/bin/echo
}

new_fs_ext3 ()
{
/bin/echo "Starting newfs ext3 "
/sbin/mkfs.ext3 /dev/ram0 <<EOF
y
EOF
/bin/mount /dev/ram0 /mnt/fs
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
#/sbin/zfs get recordsize
#/sbin/zdb -U /var/tmp/zpool.cache |grep ashift
/bin/mount |grep mdpool
/bin/df -H |grep mdpool
/bin/echo
}

new_fs_zfs_checksumoff ()
{
/bin/echo "Starting newfs ZFS checksum=off"
/sbin/zpool create mdpool /dev/ram0
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set checksum=off mdpool
/sbin/zfs set mountpoint=/mnt/fs mdpool
#/sbin/zfs get recordsize
#/sbin/zdb -U /var/tmp/zpool.cache |grep ashift
/bin/mount |grep mdpool
/bin/df -H |grep mdpool
/bin/echo
}

stop_fs_ext4 ()
{
/bin/echo "Stoping newfs ext4 "
umount -f /mnt/fs
/bin/echo
}

stop_fs_ext3 ()
{
/bin/echo "Stoping newfs ext3 "
umount -f /mnt/fs
/bin/echo
}

stop_fs_ext2 ()
{
/bin/echo "Stoping newfs ext2 "
umount -f /mnt/fs
/bin/echo
}

stop_fs_btrfs ()
{
/bin/echo "Stoping newfs btrfs "
umount -f /mnt/fs
/bin/echo
}

stop_fs_xfs ()
{
/bin/echo "Stoping newfs xfs "
umount -f /mnt/fs
/bin/echo
}

stop_fs_jfs ()
{
/bin/echo "Stoping newfs jfs "
umount -f /mnt/fs
/bin/echo
}

stop_fs_zfs ()
{
/bin/echo "Stoping newfs zfs "
umount -f /mnt/fs
sleep 5
/sbin/zpool destroy mdpool
/bin/echo
}

stop_fs_zfs_checksumoff ()
{
/bin/echo "Stoping newfs zfs checksum=off "
umount -f /mnt/fs
sleep 5
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

new_fs_zfs
TESTNAME="-m zfs"
test_bonnie
#test_dd
stop_fs_zfs

new_fs_zfs_checksumoff
TESTNAME="-m zfs_checksumoff"
test_bonnie
#test_dd
stop_fs_zfs_checksumoff

new_fs_btrfs
TESTNAME="-m btrfs"
test_bonnie
#test_dd
stop_fs_btrfs

#stop



















