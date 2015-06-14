#!/usr/bin/env bash

echo "[PREPARING STAGING]"
if [ ! -d staging ]; then
    mkdir staging
fi

if [ ! -f NOOBS_lite_*.zip ]; then
    echo "Can't find NOOBS_lite_*.zip, please download it and place it in this dir"
    exit 1
fi

if [ ! -f geNtOOBS-latest.tar.xz ]; then
    echo "Can't find geNtOOBS-latest.tar.xz, please download it and place it in this dir"
    exit 1
fi

echo "[SETTING UP NOOBS]"
if [ ! -d staging/os ]; then
    unzip -d staging NOOBS_lite_*.zip
else
    echo "[SKIPPING NOOBS]"
fi

echo "[SETTING UP GENTOOBS]"
if [ ! -d staging/os/Gentoo ]; then
    tar xavf geNtOOBS-latest.tar.xz -C staging/os
else
    echo "[SKIPPING GENTOOBS]"
fi

echo "[SETTING UP SILENTINSTALL]"
if ! grep silentinstall staging/recovery.cmdline > /dev/null; then
    sed -i 's/elevator=deadline/elevator=deadline silentinstall/' staging/recovery.cmdline
else
    echo "[SKIPPING SILENTINSTALL]"
fi
