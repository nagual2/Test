#!/bin/sh

VERSION="test_fs_bsd.sh v0.01"

# Мы небудем тестировать gjournal из-за необходимости перегрузки в однопользовательский режим.
# Внимание данные на диске будут утеряны. Диск будет перезаписан.
DISKDEV="da1" # !!!
DISKSIZE="20G"
TESTSIZE="-s 19g:128k -r 800m"
TEST2SIZE="bs=1M count=19922944"
LOGFILE="test_fs_bsd.log"
exec 1>$LOGFILE 2>&1
/bin/echo $VERSION
/bin/echo

new_fs_ufs ()
{
/bin/echo "Starting newfs UFS $UFS "
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -s $DISKSIZE -t freebsd-ufs -l disk0 $DISKDEV
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/newfs $UFS /dev/${DISKDEV}p1
/sbin/tunefs -p /dev/${DISKDEV}p1
/bin/mkdir -p /mnt/fs
/bin/chmod 777 /mnt/fs
/sbin/mount /dev/${DISKDEV}p1 /mnt/fs
/sbin/mount
/bin/df -H
/bin/echo
}

stop_fs_ufs ()
{
/bin/echo "Stoping UFS $UFS "
/sbin/umount -f /mnt/fs
/sbin/gpart delete -i 1 $DISKDEV
/sbin/gpart destroy $DISKDEV
/bin/echo
}

new_fs_ufs4k ()
{
/bin/echo "Starting newfs UFS4k $UFS "
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -a 4k -s $DISKSIZE -t freebsd-ufs -l disk0 $DISKDEV
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/newfs $UFS -f 4096 /dev/${DISKDEV}p1
/sbin/tunefs -p /dev/${DISKDEV}p1
/bin/mkdir -p /mnt/fs
/bin/chmod 777 /mnt/fs
/sbin/mount /dev/${DISKDEV}p1 /mnt/fs
/sbin/mount
/bin/df -H
/bin/echo
}

stop_fs_ufs4k ()
{
/bin/echo "Stoping UFS $UFS "
/sbin/umount -f /mnt/fs
/sbin/gpart delete -i 1 $DISKDEV
/sbin/gpart destroy $DISKDEV
/bin/echo
}

new_fs_zfs ()
{
/bin/echo "Starting newfs ZFS "
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -s $DISKSIZE -t freebsd-zfs -l disk0 $DISKDEV
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/zpool create mdpool /dev/${DISKDEV}p1
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set mountpoint=/mnt/fs mdpool
/sbin/zfs get recordsize
/usr/sbin/zdb -U /var/tmp/mdpool.cache |grep ashift
/sbin/mount
/bin/df -H
/bin/echo
}

new_fs_zfs4k ()
{
/bin/echo "Starting newfs ZFS4k "
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -a 4k -s $DISKSIZE -t freebsd-zfs -l disk0 $DISKDEV
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/gnop create -S 4096 /dev/gpt/disk0
/sbin/zpool create -o cachefile=/var/tmp/mdpool.cache mdpool /dev/gpt/disk0.nop
/sbin/zpool export mdpool
/sbin/gnop destroy /dev/gpt/disk0.nop
/sbin/zpool import -o cachefile=/var/tmp/mdpool.cache mdpool
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set mountpoint=/mnt/fs mdpool
/sbin/zfs get recordsize
/usr/sbin/zdb -U /var/tmp/mdpool.cache |grep ashift
/sbin/mount
/bin/df -H
/bin/echo
}

stop_fs_zfs4k ()
{
/bin/echo "Stoping fs ZFS "
/sbin/umount -f /mnt/fs
/sbin/zpool destroy mdpool
/sbin/gpart delete -i 1 $DISKDEV
/sbin/gpart destroy $DISKDEV
/bin/echo
}

stop_fs_zfs ()
{
/bin/echo "Stoping fs ZFS "
/sbin/umount -f /mnt/fs
/sbin/zpool destroy mdpool
/sbin/gpart delete -i 1 $DISKDEV
/sbin/gpart destroy $DISKDEV
/bin/echo
}

new_fs_zfs_checksumoff ()
{
/bin/echo "Starting newfs ZFS "
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -s $DISKSIZE -t freebsd-zfs -l disk0 $DISKDEV
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/zpool create mdpool /dev/${DISKDEV}p1
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set checksum=off mdpool
/sbin/zfs set mountpoint=/mnt/fs mdpool
/sbin/zfs get recordsize
/usr/sbin/zdb -U /var/tmp/mdpool.cache |grep ashift
/sbin/mount
/bin/df -H
/bin/echo
}

new_fs_zfs4k_checksumoff ()
{
/bin/echo "Starting newfs ZFS4k "
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -a 4k -s $DISKSIZE -t freebsd-zfs -l disk0 $DISKDEV
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/gnop create -S 4096 /dev/gpt/disk0
/sbin/zpool create -o cachefile=/var/tmp/mdpool.cache mdpool /dev/gpt/disk0.nop
/sbin/zpool export mdpool
/sbin/gnop destroy /dev/gpt/disk0.nop
/sbin/zpool import -o cachefile=/var/tmp/mdpool.cache mdpool
/sbin/zpool list
/sbin/zpool status
/sbin/zfs set checksum=off mdpool
/sbin/zfs set mountpoint=/mnt/fs mdpool
/sbin/zfs get recordsize
/usr/sbin/zdb -U /var/tmp/mdpool.cache |grep ashift
/sbin/mount
/bin/df -H
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

# Тестируем ;-)

UFS="-O2"
new_fs_ufs
TESTNAME="-m UFS-O2"
#test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2"
#test_bonnie
#test_dd
stop_fs_ufs4k

UFS="-O2 -U"
new_fs_ufs
TESTNAME="-m UFS-O2-U"
#test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2-U"
#test_bonnie
#test_dd
stop_fs_ufs4k

UFS="-O2 -U -j"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j"
#test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U -j"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2-U-j"
#test_bonnie
#test_dd
stop_fs_ufs4k

UFS="-O2 -U -j -t"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j-t"
#test_bonnie
#test_dd
stop_fs_ufs

UFS="-O2 -U -j -t"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2-U-j-t"
#test_bonnie
#test_dd
stop_fs_ufs4k

/bin/echo "Enable ZFS prefetch "
/bin/echo
/sbin/sysctl vfs.zfs.prefetch_disable=0

new_fs_zfs
TESTNAME="-m ZFS"
#test_bonnie
#test_dd
stop_fs_zfs

new_fs_zfs4k
TESTNAME="-m ZFS4k"
#test_bonnie
#test_dd
stop_fs_zfs4k

# ZFS с checksum=off.
new_fs_zfs_checksumoff
TESTNAME="-m ZFS_no_checksum"
#test_bonnie
#test_dd
stop_fs_zfs

# ZFS с checksum=off.
new_fs_zfs4k_checksumoff
TESTNAME="-m ZFS4k_no_checksum"
#test_bonnie
#test_dd
stop_fs_zfs4k

/bin/echo "Disable ZFS prefetch "
/bin/echo
/sbin/sysctl vfs.zfs.prefetch_disable=1

new_fs_zfs
TESTNAME="-m ZFS_no_prefetch"
#test_bonnie
#test_dd
stop_fs_zfs

new_fs_zfs4k
TESTNAME="-m ZFS4k_no_prefetch"
#test_bonnie
#test_dd
stop_fs_zfs4k

new_fs_zfs_checksumoff
TESTNAME="-m ZFS_no_checksum_&_no_prefetch"
#test_bonnie
#test_dd
stop_fs_zfs

new_fs_zfs4k_checksumoff
TESTNAME="-m ZFS4k_no_checksum_&_no_prefetch"
#test_bonnie
#test_dd
stop_fs_zfs4k

exit 0





