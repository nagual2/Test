#!/bin/sh

exec 1>/dev/null 2>&1
/bin/sleep 5
while true
    do /usr/sbin/e4defrag /dev/ram0
done
