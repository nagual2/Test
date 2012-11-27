#!/bin/sh

VERSION="test_fs_memdisk_bsd.sh v0.02"

# Создаем диск в памяти на 6 гиг (всего 8) итого системе остаётся 2 гига.
DISKDEV="md0"
DISKSIZE="7G" # 7168M
TESTSIZE="-s 6600m:128k -r 800m"
TEST2SIZE="bs=1M count=6600"
LOGFILE="test_fs_memdisk_bsd.log"
exec 1>$LOGFILE 2>&1
TESTBONNIE="NO"
TESTDD="NO"
CHECKSUM="ON"
ZIL="ON"
TEST01="YES" # "-m UFS    -O2"
TEST02="YES" # "-m UFS 4k -O2"
TEST03="YES" # "-m UFS    -O2 -U"
TEST04="YES" # "-m UFS 4k -O2 -U" & "-m UFS4k -O2 -U & snap"
TEST05="YES" # "-m UFS    -O2 -U -j"
TEST06="YES" # "-m UFS 4k -O2 -U -j"
TEST07="YES" # "-m UFS    -O2 -U -j -t"
TEST08="YES" # "-m UFS 4k -O2 -U -j -t"
TEST09="YES" # "-m ZFS"
TEST10="YES" # "-m ZFS 4k"
TEST11="YES" # "-m ZFS    checksum off"
TEST12="YES" # "-m ZFS 4k checksum off"
TEST13="YES" # "-m ZFS                   prefetch off"
TEST14="YES" # "-m ZFS 4k                prefetch off"
TEST15="YES" # "-m ZFS    checksum off & prefetch off"
TEST16="YES" # "-m ZFS 4k checksum off & prefetch off"
TEST17="YES" # "-m ZFS    checksum off & prefetch off & ZIL off"
TEST18="YES" # "-m ZFS 4k checksum off & prefetch off & ZIL off"
TEST19="YES" # "-m ZFS    checksum off & prefetch off & ZIL off"
TEST20="YES" # "-m ZFS 4k checksum off & prefetch off & ZIL off"

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
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add -t freebsd-ufs -l disk0 $DISKDEV # -s $DISKSIZE 
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/newfs $UFS /dev/${DISKDEV}p1
/sbin/tunefs -p /dev/${DISKDEV}p1
/sbin/mount /dev/${DISKDEV}p1 /mnt/fs
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
/sbin/gpart add -a 4k  -t freebsd-ufs -l disk0 $DISKDEV # -s $DISKSIZE
/sbin/gpart list $DISKDEV
/sbin/gpart show $DISKDEV
/sbin/newfs $UFS -f 4096 /dev/${DISKDEV}p1
/sbin/tunefs -p /dev/${DISKDEV}p1
/sbin/mount /dev/${DISKDEV}p1 /mnt/fs
/sbin/mount
/bin/df -H
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
/sbin/gpart create -s gpt /dev/$DISKDEV
/sbin/gpart add  -t freebsd-zfs -l disk0 $DISKDEV # -s $DISKSIZE
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
/sbin/gpart add -a 4k  -t freebsd-zfs -l disk0 $DISKDEV # -s $DISKSIZE
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

if [ $TEST01 == "YES" ]; then
UFS="-O2"
new_fs_ufs
TESTNAME="-m UFS-O2"
/bin/echo "TEST01 -m UFS-O2"
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
/bin/echo "TEST02 -m UFS4k-O2"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
test_dd
fi
stop_fs_ufs
fi

if [ $TEST03 == "YES" ]; then
UFS="-O2 -U"
new_fs_ufs
TESTNAME="-m UFS-O2-U"
/bin/echo "TEST03 -m UFS-O2-U"
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
/bin/echo "TEST04 -m UFS4k-O2-U"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
TESTNAME="-m UFS4k-O2-U-snap"
/bin/echo "TEST04 -m UFS4k-O2-U-snap"
rm /mnt/fs/*
mount -u -o snapshot /mnt/fs/.snap/test /mnt/fs
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs
fi

if [ $TEST05 == "YES" ]; then
UFS="-O2 -U -j"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j"
/bin/echo "TEST05 -m UFS-O2-U-j"
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
/bin/echo "TEST06 -m UFS4k-O2-U-j"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs
fi

if [ $TEST07 == "YES" ]; then
UFS="-O2 -U -j -t"
new_fs_ufs
TESTNAME="-m UFS-O2-U-j-t"
/bin/echo "TEST07 -m UFS-O2-U-j-t"
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
/bin/echo "TEST08 -m UFS4k-O2-U-j-t"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_ufs
fi

/bin/echo "Enable ZFS prefetch "
/bin/echo
/sbin/sysctl vfs.zfs.prefetch_disable=0

if [ $TEST09 == "YES" ]; then
new_fs_zfs
TESTNAME="-m ZFS"
/bin/echo "TEST09 -m ZFS"
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
/bin/echo "TEST10 -m ZFS4k"
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
/bin/echo "TEST11 -m ZFS_no_cs"
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
/bin/echo "TEST12 -m ZFS4k_no_cs"
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
/bin/echo "TEST13 -m ZFS_no_pf"
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
/bin/echo "TEST14 -m ZFS4k_no_pf"
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
/bin/echo "TEST15 -m ZFS_no_cs_&_no_pf"
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
/bin/echo "TEST16 -m ZFS4k_no_cs&no_pf"
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
/bin/echo "TEST17 -m ZFS_no_cs&no_pf&no_zil"
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
/bin/echo "TEST18 -m ZFS4k_no_cs&no_pf&no_zil"
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
/bin/echo "TEST19 -m ZFS_no_cs&no_pf&no_zil"
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
/bin/echo "TEST20 -m ZFS4k_no_cs&no_pf&no_zil"
if [ $TESTBONNIE == "YES" ]; then
    test_bonnie
elif [ $TESTDD == "YES" ]; then
    test_dd
fi
stop_fs_zfs
fi

#stop
stop_md
exit 0





