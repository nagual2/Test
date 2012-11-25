#!/bin/sh

mount_cd9660  /dev/cd0 /media

DIST="/media/usr/freebsd-dist"
DISKDEV1="da1"
DISKDEV2="da2"
SWAPSIZE="1G"
LOGFILE="bsd_install_to_zfs_mirror.sh.log"
exec 1>$LOGFILE 2>&1
ZPOOL="zroot"
HOSTNAME="BSD"
MNT="/mnt2"

mkdir -p $MNT
sysctl kern.geom.debugflags=0x10

/bin/echo "Starting newfs ZFS "
/sbin/gpart create -s gpt $DISKDEV1
/sbin/gpart create -s gpt $DISKDEV2
/bin/sync

/sbin/gpart add -a 4k -b 34 -s 64k -t freebsd-boot $DISKDEV1
/sbin/gpart add -a 4k -t freebsd-zfs -l disk0 $DISKDEV1
/bin/sync

/sbin/gpart add -a 4k -b 34 -s 64k -t freebsd-boot $DISKDEV2
/sbin/gpart add -a 4k -t freebsd-zfs -l disk1 $DISKDEV2
/bin/sync

/sbin/gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $DISKDEV1
/sbin/gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $DISKDEV2
/bin/sync

/sbin/gnop create -S 4096 /dev/gpt/disk0
/sbin/gnop create -S 4096 /dev/gpt/disk1
/bin/sync

/sbin/zpool create -m $MNT -f -o cachefile=/var/tmp/$ZPOOL.cache $ZPOOL mirror /dev/gpt/disk0.nop /dev/gpt/disk1.nop
/sbin/zpool export $ZPOOL
/sbin/gnop destroy /dev/gpt/disk0.nop
/sbin/gnop destroy /dev/gpt/disk1.nop
/sbin/zpool import -o cachefile=/var/tmp/$ZPOOL.cache $ZPOOL
/sbin/zpool set bootfs=$ZPOOL $ZPOOL
/sbin/zpool list
/sbin/zpool status
/sbin/zfs get recordsize
/usr/sbin/zdb -U /var/tmp/$ZPOOL.cache |grep ashift
/sbin/mount
/bin/df -H
/bin/sync

/sbin/zfs set checksum=fletcher4 $ZPOOL

/sbin/zfs create -V $SWAPSIZE $ZPOOL/swap # zfs create -V 4gb -o org.freebsd:swap=on -o volblocksize=4K -o checksum=off systor/swap
/sbin/zfs set org.freebsd:swap=on $ZPOOL/swap
/sbin/zfs set checksum=off $ZPOOL/swap
/bin/sync

/sbin/zfs create -o mountpoint=$MNT/usr $ZPOOL/usr
/sbin/zfs create -o mountpoint=$MNT/usr/ports $ZPOOL/usr/ports
/sbin/zfs create -o mountpoint=$MNT/usr/src $ZPOOL/usr/src
/sbin/zfs create -o mountpoint=$MNT/usr/home $ZPOOL/usr/home
/sbin/zfs create -o mountpoint=$MNT/var $ZPOOL/var
/sbin/zfs create -o mountpoint=$MNT/var/db $ZPOOL/var/db
/sbin/zfs create -o mountpoint=$MNT/var/tmp $ZPOOL/var/tmp
/sbin/zfs create -o mountpoint=$MNT/tmp $ZPOOL/tmp
/bin/sync

chmod 1777 $MNT/tmp $MNT/var/tmp

cd $DIST
export DESTDIR=$MNT
for file in base.txz doc.txz kernel.txz ports.txz src.txz; do (cat $file | tar --unlink -xpJf - -C ${DESTDIR:-/}) ; done

cat << EOF >> $MNT/etc/rc.conf
#!/bin/sh
ipv6_enable="NO"
rc_info="YES"		# Enables display of informational messages at boot.

keymap=ru.koi8-r
keychange="61 ^[[K"
scrnmap=koi8-r2cp866
font8x16=cp866b-8x16
font8x14=cp866-8x14
font8x8=cp866-8x8
saver="blank"
keyrate="fast"

mousechar_start="3"
moused_enable="YES"
moused_port="/dev/psm0"
moused_type="auto"

network_interfaces="auto"	# List of network interfaces (or "auto").
ifconfig_lo0="inet 127.0.0.1  netmask 255.255.255.0"
defaultrouter="192.168.0.1"
ifconfig_em0="inet 192.168.0.88 netmask 255.255.255.0"

hostname=$HOSTNAME

zfs_enable="YES"
kern_securelevel_enable="NO"
linux_enable="YES"
sshd_enable="YES"
sshd_flags="-u0"
usbd_enable="NO"

#fsck_y_enable="YES"
background_fsck="NO"

sendmail_enable="NONE"		# Run the sendmail inbound daemon (YES/NO).
sendmail_flags="-L sm-mta -bd -q30m" # Flags to sendmail (as a server)
sendmail_submit_enable="NO"	# Start a localhost-only MTA for mail submission
sendmail_submit_flags="-L sm-mta -bd -q30m -ODaemonPortOptions=Addr=localhost"
# Flags for localhost-only MTA
sendmail_outbound_enable="NO"	# Dequeue stuck mail (YES/NO).
sendmail_outbound_flags="-L sm-queue -q30m" # Flags to sendmail (outbound only)
sendmail_msp_queue_enable="NO"	# Dequeue stuck clientmqueue mail (YES/NO).
sendmail_msp_queue_flags="-L sm-msp-queue -Ac -q30m"
# Flags for sendmail_msp_queue daemon.				
# to their chrooted counterparts.

nfs_reserved_port_only="NO"
ntpdate_flags="ntp.ucsd.edu"
ntpdate_enable="NO"
xntpd_enable="NO"
net_snmpd_enable="NO"
inetd_enable="NO"
inetd_program="/usr/sbin/inetd"	# path to inetd, if you want a different one.
inetd_flags="-wW -C 60"		# Optional flags to inetd

portmap_enable="NO"
nfs_server_enable="NO"
nfs_client_enable="NO"
tcp_drop_synfin="YES"
icmp_drop_redirect="YES"
icmp_log_redirect="NO"
syslogd_enable="YES"
syslogd_flags="-ss"
accounting_enable="NO"
check_quotas="NO"
clear_tmp_enable="YES"		# Clear /tmp at startup.
cron_enable="YES"		# Run the periodic job daemon.
named_enable="YES"		# Run named, the DNS server (or NO).

#devd_enable="YES".
#devfs_system_ruleset="devfsrules_common".
ldconfig_paths="/usr/lib/compat /usr/local/lib /usr/local/kde4/lib /usr/local/lib/compat/pkg"

# Denyhosts Startup.
denyhosts_enable="YES"

EOF

cat << EOF >> $MNT/etc/fstab
# Device	Mountpoint	FStype	Options	Dump	Pass#
#linproc 	/compat/linux/proc 	linprocfs	rw	0	0

EOF

cat << EOF >> $MNT/etc/resolv.conf
search $HOSTNAME
domain $HOSTNAME
nameserver 127.0.0.1
#nameserver 8.8.8.8

EOF

cat << EOF >> $MNT/boot/loader.conf
zfs_load="YES"
vfs.root.mountfrom="zfs:$ZPOOL"

autoboot_delay="1"
beastie_disable="YES"

linux_load="YES"			# Linux emulation
#lindev_load="NO"		# Linux-specific pseudo devices (see lindev(4))
linprocfs_load="YES"		# Linux compatibility process filesystem
linsysfs_load="YES"		# Linux compatibility system filesystem
aio_load="YES"		# Linux compatibility system filesystem

#ipfw_load="YES"			# Firewall
#ipfw_nat_load="YES"

#if_tap_load="YES"		# Ethernet tunnel software network interface

# Kernel Options
kern.ipc.shmseg=1024
kern.ipc.shmmni=1024
kern.maxproc=10000

vm.pmap.pg_ps_enabled="0"
#hw.mca.enabled=1
kern.timecounter.hardware=i8254
hw.pci.enable_msix=0
hw.pci.enable_msi=0
net.inet.tcp.tso=0

EOF

cp /var/tmp/$ZPOOL.cache $MNT/boot/zfs/zpool.cache
zpool set cachefile=$MNT/boot/zfs/zpool.cache $ZPOOL
/bin/sync

/sbin/zfs unmount -a
/bin/sync

/sbin/zfs set mountpoint=legacy $ZPOOL
/sbin/zfs set mountpoint=/tmp $ZPOOL/tmp
/sbin/zfs set mountpoint=/usr $ZPOOL/usr
/sbin/zfs set mountpoint=/usr/ports $ZPOOL/usr/ports
/sbin/zfs set mountpoint=/usr/src $ZPOOL/usr/src
/sbin/zfs set mountpoint=/usr/home $ZPOOL/usr/home
/sbin/zfs set mountpoint=/var $ZPOOL/var
/sbin/zfs set mountpoint=/var/db $ZPOOL/var/db
/sbin/zfs set mountpoint=/var/tmp $ZPOOL/var/tmp
/bin/sync
rm $MNT

exit 0

