Сводный набор тестов для систем на базе Linux и FreeBSD.
По мотивам http://actika.livejournal.com/619.html а так же горячих споров на http://opennet.ru :))
Для тестов необходима машина с 8ГГб оперативной памяти. Следует отдельно поговорить о цифрах используемых в тестах,
Как вы наверно заметили в зависимости от fs колличество свободного места может сильно отличаться:

/dev/ram0 on /mnt/fs type ext4 (rw)
/dev/ram0       7,5G  244M  6,9G   4% /mnt/fs

/dev/ram0 on /mnt/fs type ext3 (rw)
/dev/ram0       7,4G  151M  6,9G   3% /mnt/fs

/dev/ram0 on /mnt/fs type ext2 (rw)
/dev/ram0       7,4G   17M  7,1G   1% /mnt/fs

/dev/ram0 on /mnt/fs type xfs (rw)
/dev/ram0       7,6G   34M  7,5G   1% /mnt/fs

/dev/ram0 on /mnt/fs type jfs (rw)
/dev/ram0       7,5G  1,1M  7,5G   1% /mnt/fs

/dev/ram0 on /mnt/fs type reiserfs (rw)
/dev/ram0       7,6G   34M  7,5G   1% /mnt/fs

NAME     SIZE  ALLOC   FREE    CAP  DEDUP  HEALTH  ALTROOT
mdpool  6,94G  95,5K  6,94G     0%  1.00x  ONLINE  -
mdpool          7,4G   22k  7,4G   1% /mnt/fs

/dev/ram0 on /mnt/fs type btrfs (rw)
/dev/ram0       7,6G   58k  6,8G   1% /mnt/fs

/dev/md0: 7168.0MB (14680064 sectors) block size 32768, fragment size 4096
/dev/md0      7.3G    8.2k    6.7G     0%    /mnt/fs

/dev/md0: 7168.0MB (14680064 sectors) block size 32768, fragment size 4096
/dev/md0      7.3G    8.2k    6.7G     0%    /mnt/fs

/dev/md0: 7168.0MB (14680064 sectors) block size 32768, fragment size 4096
/dev/md0      7.3G     33M    6.7G     1%    /mnt/fs

/dev/md0: 7168.0MB (14680064 sectors) block size 32768, fragment size 4096
/dev/md0      7.3G     33M    6.7G     1%    /mnt/fs

NAME     SIZE  ALLOC   FREE    CAP  DEDUP  HEALTH  ALTROOT
mdpool        7.3G     31k    7.3G     0%    /mnt/fs
mdpool  6,94G    77K  6,94G     0%  1.00x  ONLINE  -


Кроме того при приближении заполненности файлами к 100% может быть сильное падение производительности.
Итак:
TESTSIZE="-s 6600m:128k -r 800m"
под тест bonnie++ используем 6600 мегабайт блоками 128k и под кеширование 800 мегабайт.


