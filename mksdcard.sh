#!/usr/bin/env bash

if [[ -z "$1" ]]; then
    echo "Include the target disk as the first argument"
    exit 1
fi

if [[ -z "$2" ]]; then
    echo "Include a safe mountpoint as the second argument"
    exit 1
fi

echo "[THIS SCRIPT USES ROOT, C-c IF YOU HAVEN'T READ IT]"

sleep 5

echo "[GIVE ME ROOT PLEASE]"
sudo echo "[GOT ROOT]"

echo "[PREPARING DISK]"
sudo umount "$1"*

echo "[PREPARING DISK]"
sudo sfdisk $1 <<EOF
# partition table of $1
unit: sectors

/dev/sdb1 : start=     2048, size= , Id= c
/dev/sdb2 : start=        0, size=        0, Id= 0
/dev/sdb3 : start=        0, size=        0, Id= 0
/dev/sdb4 : start=        0, size=        0, Id= 0
EOF
sudo mkfs.vfat -F 32 "$1"1
sudo mount "$1"1 $2

echo "[COPYING FILES]"
sudo cp -r staging/* $2
sudo sync
sudo umount $2
echo "[DONE]"
