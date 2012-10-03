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
/bin/mkdir -p /mnt/ramdisk
/bin/mkdir -p /mnt/fs
/bin/mount -t ramfs -omasxsize=$DISKSIZE ramdisk /mnt/ramdisk
/bin/dd if=/dev/zero of=/mnt/ramdisk/fs bs=1M count=6144
/bin/echo
}

stop_md ()
{
/bin/echo "Shutting memdisk "
/bin/umount -f /mnt/ramdisk
/bin/echo
}

new_fs_ext4 ()
{
/bin/echo "Starting newfs ext4 "
/sbin/mkfs.ext4 /mnt/ramdisk/fs <<EOF
y
EOF
/bin/mount -o loop /mnt/ramdisk/fs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

new_fs_ext3 ()
{
/bin/echo "Starting newfs ext3 "
/sbin/mkfs.ext3 /mnt/ramdisk/fs <<EOF
y
EOF
/bin/mount -o loop /mnt/ramdisk/fs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

new_fs_ext2 ()
{
/bin/echo "Starting newfs ext2 "
/sbin/mkfs.ext2 /mnt/ramdisk/fs <<EOF
y
EOF
/bin/mount -o loop /mnt/ramdisk/fs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

new_fs_btrfs ()
{
/bin/echo "Starting newfs btrfs "
/sbin/mkfs.btrfs /mnt/ramdisk/fs <<EOF
y
EOF
/bin/mount -o loop /mnt/ramdisk/fs /mnt/fs
/bin/mount
/bin/df -H
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


start_md

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

# Мы не будем ее тестировать потому что она страдает детскими болезнями.
#new_fs_btrfs
#TESTNAME="-m btrfs"
#test_bonnie
#test_dd
#stop_fs_btrfs

stop_md



















