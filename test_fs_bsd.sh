#!/bin/sh

VERSION="test_fs_bsd.sh v0.02"

# Мы небудем тестировать gjournal из-за необходимости перегрузки в однопользовательский режим.
# Внимание данные на диске будут утеряны. Диск будет перезаписан.
DISKDEV="da1" # !!!
DISKSIZE="20G"
TESTSIZE="-s 19g:128k -r 800m"
TEST2SIZE="bs=1M count=18874368" # 18G
LOGFILE="test_fs_bsd.log"
exec 1>$LOGFILE 2>&1
TESTBONNIE="NO"
TESTDD="NO"
TEST01="YES" # "-m UFS -O2"
TEST02="YES" # "-m UFS4k -O2"
TEST03="YES" # "-m UFS -O2 -U"
TEST04="YES" # "-m UFS4k -O2 -U"
TEST05="YES" # "-m UFS -O2 -U -j"
TEST06="YES" # "-m UFS4k -O2 -U -j"
TEST07="YES" # "-m UFS -O2 -U -j -t"
TEST08="YES" # "-m UFS4k -O2 -U -j -t"
TEST09="YES" # "-m ZFS"
TEST10="YES" # "-m ZFS 4k"
TEST11="YES" # "-m ZFS   checksum off"
TEST12="YES" # "-m ZFS4k checksum off"
TEST13="YES" # "-m ZFS   prefetch off"
TEST14="YES" # "-m ZFS4k prefetch off"
TEST15="YES" # "-m ZFS   checksum off & prefetch off"
TEST16="YES" # "-m ZFS4k checksum off & prefetch off"
TEST17="YES" # "-m ZFS   checksum off & prefetch off & ZIL off"
TEST18="YES" # "-m ZFS4k checksum off & prefetch off & ZIL off"
TEST19="YES" # "-m ZFS   checksum off & prefetch off & ZIL off"
TEST20="YES" # "-m ZFS4k checksum off & prefetch off & ZIL off"

/bin/echo $VERSION
/bin/echo
/sbin/dmesg |grep $DISKDEV
/sbin/camcontrol devlist
/sbin/fdisk -s /dev/$DISKDEV
/bin/mkdir -p /mnt/fs

new_fs_ufs ()
{
/bin/echo "Starting newfs UFS $UFS "
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -s $DISKSIZE -t freebsd-ufs -l disk0 $DISKDEV
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/newfs $UFS /dev/${DISKDEV}p1
/sbin/tunefs -p /dev/${DISKDEV}p1
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
/sbin/mount /dev/${DISKDEV}p1 /mnt/fs
/sbin/mount
/bin/df -H
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
if [ $CHECKSUM == "OFF" ]; then
/sbin/zfs set checksum=off mdpool
fi
if [ $ZIL == "OFF" ]; then
/sbin/zfs set sync=disabled mdpool
fi
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
if [ $CHECKSUM == "OFF" ]; then
/sbin/zfs set checksum=off mdpool
fi
if [ $ZIL == "OFF" ]; then
/sbin/zfs set sync=disabled mdpool
fi
/sbin/zfs set mountpoint=/mnt/fs mdpool
/sbin/zfs get recordsize
/usr/sbin/zdb -U /var/tmp/mdpool.cache |grep ashift
/sbin/mount
/bin/df -H
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
if [ $TEST01 == "YES" ]; then
UFS="-O2"
new_fs_ufs
TESTNAME="-m UFS-O2"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs
fi

if [ $TEST02 == "YES" ]; then
UFS="-O2"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
test_dd
fi
stop_fs_ufs4
fi

if [ $TEST03 == "YES" ]; then
UFS="-O2 -U"
new_fs_ufs
TESTNAME="-m UFS-O2-U"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs
fi

if [ $TEST04 == "YES" ]; then
UFS="-O2 -U"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2-U"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs4
fi

if [ $TEST05 == "YES" ]; then
UFS="-O2 -U -j"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs
fi

if [ $TEST06 == "YES" ]; then
UFS="-O2 -U -j"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2-U-j"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs4
fi

if [ $TEST07 == "YES" ]; then
UFS="-O2 -U -j -t"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j-t"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs
fi

if [ $TEST08 == "YES" ]; then
UFS="-O2 -U -j -t"
new_fs_ufs4k
TESTNAME="-m UFS4k-O2-U-j-t"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs4
fi

/bin/echo "Enable ZFS prefetch "
/bin/echo
/sbin/sysctl vfs.zfs.prefetch_disable=0

if [ $TEST09 == "YES" ]; then
new_fs_zfs
TESTNAME="-m ZFS"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

if [ $TEST10 == "YES" ]; then
new_fs_zfs4k
TESTNAME="-m ZFS4k"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi


CHECKSUM="OFF"
if [ $TEST11 == "YES" ]; then
new_fs_zfs
TESTNAME="-m ZFS_no_cs"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

if [ $TEST12 == "YES" ]; then
new_fs_zfs4k
TESTNAME="-m ZFS4k_no_cs"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

/bin/echo "Disable ZFS prefetch "
/bin/echo
/sbin/sysctl vfs.zfs.prefetch_disable=1

CHECKSUM="ON"
if [ $TEST13 == "YES" ]; then
new_fs_zfs
TESTNAME="-m ZFS_no_pf"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

if [ $TEST14 == "YES" ]; then
new_fs_zfs4k
TESTNAME="-m ZFS4k_no_pf"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

CHECKSUM="OFF"
if [ $TEST15 == "YES" ]; then
new_fs_zfs
TESTNAME="-m ZFS_no_cs_&_no_pf"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

if [ $TEST16 == "YES" ]; then
new_fs_zfs4k
TESTNAME="-m ZFS4k_no_cs&no_pf"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

CHECKSUM="ON"
ZIL="OFF"
if [ $TEST17 == "YES" ]; then
new_fs_zfs
TESTNAME="-m ZFS_no_cs&no_pf&no_zil"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

if [ $TEST18 == "YES" ]; then
new_fs_zfs4k
TESTNAME="-m ZFS4k_no_cs&no_pf&no_zil"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

CHECKSUM="OFF"
if [ $TEST19 == "YES" ]; then
new_fs_zfs
TESTNAME="-m ZFS_no_cs&no_pf&no_zil"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

if [ $TEST20 == "YES" ]; then
new_fs_zfs4k
TESTNAME="-m ZFS4k_no_cs&no_pf&no_zil"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

#stop
exit 0



