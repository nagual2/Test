#!/bin/sh

VERSION="test_fs_ubuntu.sh v0.01"

# apt-get install lvm2
# Внимание данные на диске будут утеряны. Диск будет перезаписан.
DISKDEV="sdb" # !!!
DISKSIZE="20G"
TESTSIZE="-s 19g:128k -r 800m"
TEST2SIZE="bs=1M count=19922944"
LOGFILE="test_fs_ubuntu.log"
exec 1>$LOGFILE 2>&1
/bin/echo $VERSION
/bin/echo
/bin/dmesg |grep $DISKDEV
/sbin/fdisk -l /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/bin/mkdir -p /mnt/fs

new_fs_ext4 ()
{
/bin/echo "Starting newfs ext4 "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.ext4 /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/sbin/tune2fs -l /dev/datavg/testfs
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_ext4 ()
{
/bin/echo "Stoping newfs ext4 "
/bin/umount -f /mnt/fs
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
/bin/echo
}

new_fs_ext4_defrag ()
{
/bin/echo "Starting newfs ext4 defrag "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.ext4 /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/sbin/tune2fs -l /dev/datavg/testfs
/bin/mount
/bin/df -H
/bin/echo "Starting defrag "
/bin/echo
./defrag.sh &
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

new_fs_ext3 ()
{
/bin/echo "Starting newfs ext3 "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.ext3 /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/sbin/tune2fs -l /dev/datavg/testfs
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_ext3 ()
{
/bin/echo "Stoping newfs ext3 "
/bin/umount -f /mnt/fs
/bin/echo
}

new_fs_ext2 ()
{
/bin/echo "Starting newfs ext2 "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.ext2 /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_ext2 ()
{
/bin/echo "Stoping newfs ext2 "
/bin/umount -f /mnt/fs
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
/bin/echo
}

new_fs_xfs ()
{
/bin/echo "Starting newfs xfs "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.xfs -f /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_xfs ()
{
/bin/echo "Stoping newfs xfs "
/bin/umount -f /mnt/fs
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
/bin/echo
}

new_fs_jfs ()
{
/bin/echo "Starting newfs jfs "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.jfs /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_jfs ()
{
/bin/echo "Stoping newfs jfs "
/bin/umount -f /mnt/fs
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
/bin/echo
}

new_fs_reiserfs ()
{
/bin/echo "Starting newfs reiserfs "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.reiserfs /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_reiserfs ()
{
/bin/echo "Stoping newfs jfs "
/bin/umount -f /mnt/fs
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
/bin/echo
}

new_fs_zfs ()
{
/bin/echo "Starting newfs ZFS "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/zpool create mdpool /dev/datavg/testfs
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set mountpoint=/mnt/fs mdpool
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_zfs ()
{
/bin/echo "Stoping newfs zfs "
/bin/umount -f /mnt/fs
/bin/sleep 5
/sbin/zpool destroy mdpool
/bin/sleep 5
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
/bin/echo
}

new_fs_zfs_checksumoff ()
{
/bin/echo "Starting newfs ZFS checksum=off "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/zpool create mdpool /dev/datavg/testfs
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set checksum=off mdpool
/sbin/zfs set mountpoint=/mnt/fs mdpool
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_zfs_checksumoff ()
{
/bin/echo "Stoping newfs zfs checksum=off "
/bin/umount -f /mnt/fs
/bin/sleep 5
/sbin/zpool destroy mdpool
/bin/sleep 5
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
/bin/echo
}

new_fs_btrfs ()
{
/bin/echo "Starting newfs btrfs "
/sbin/pvcreate /dev/$DISKDEV
/sbin/pvdisplay /dev/$DISKDEV
/sbin/vgcreate datavg /dev/$DISKDEV
/sbin/vgdisplay datavg
/sbin/lvcreate --name testfs --size $DISKSIZE datavg
/sbin/lvdisplay datavg/testfs
/sbin/mkfs.btrfs /dev/datavg/testfs <<EOF
y
EOF
/bin/mount /dev/datavg/testfs /mnt/fs
/bin/mount
/bin/df -H
/bin/echo
}

stop_fs_btrfs ()
{
/bin/echo "Stoping newfs btrfs "
/bin/umount -f /mnt/fs
/sbin/lvremove datavg <<EOF
y
EOF
/sbin/vgremove datavg
/sbin/pvremove /dev/$DISKDEV
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



















