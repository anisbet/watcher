#!/bin/bash
ls /home/anisbet/Dev/EPL/Watcher/TestDir/*.flat | while read line
do
    if egrep "BROKEN" $line; then
        sleep 5
        echo "uh, oh" >&2
        mv $line $line.fail
        continue
    fi
    sleep 3
    echo "loaded $line"
    mv $line $line.done
done
exit 0
