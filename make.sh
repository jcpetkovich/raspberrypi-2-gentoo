#!/usr/bin/env bash

TARGET_CHOST=armv7a-hardfloat-linux-gnueabi

echo "[THIS SCRIPT USES ROOT, C-c IF YOU HAVEN'T READ IT]"

sleep 5

echo "[GIVE ME ROOT PLEASE]"
sudo echo "[GOT ROOT]"

echo "[PREPARING STAGING]"
if [ ! -d staging ]; then
    mkdir staging
fi

if [ ! -f stage3-armv7a_hardfp-*.tar.bz2 ]; then
    echo "Can't find stage3, download stage3-armv7a_hardfp-*.tar.bz2"
    exit 1
fi

if [ ! -f portage-latest.tar.bz2 ]; then
    echo "Can't find portage, download portage-latest.tar.bz2"
    exit 1
fi

if [ ! -f NOOBS_lite_*.zip ]; then
    echo "Can't find NOOBS_lite_*.zip, please download it and place it in this dir"
    exit 1
fi

if [ ! -d staging/usr/portage ]; then

    echo "[SETTING UP ROOTFS (need root)]"
    sudo tar xavf stage3-armv7a_hardfp-*.tar.bz2 -C staging
    sudo tar xavf portage-latest.tar.bz2 -C staging/usr/
else
    echo "  [SKIPPING BASIC ROOTFS SETUP]"
fi

echo "[BUILDING KERNEL]"
if [ ! -f linux/arch/arm/boot/uImage ]; then

    pushd linux > /dev/null
    if [ ! -f .config ]; then
        make mrproper
        make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- bcm2709_defconfig
    fi
    make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- menuconfig
    make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- -j5
    make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- -j5 modules

    echo "[INSTALLING KERNEL]"
    sudo make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- INSTALL_MOD_PATH=../staging modules_install
    popd

    sudo cp linux/arch/arm/boot/zImage staging/boot/kernel7.img
else
    echo "  [SKIPPING KERNEL]"
fi

echo "[INSTALLING FIRMWARE]"
if [ ! -d staging/opt/vc ]; then
    sudo cp -a firmware/boot/* staging/boot
else
    echo "  [SKIPPING FIRWMARE]"
fi

echo "[INSTALLING OPTIONAL SOFTWARE]"
if [ ! -d staging/opt/vc ]; then
    sudo cp -a firmware/hardfp/opt/vc staging/opt
    sudo cp -a firmware/documentation staging/usr/doc/libraspberrypi-doc
else
    echo "  [SKIPPING OPTIONAL SOFTWARE]"
fi

echo "[BUILDING NOOBSOS]"
if [ ! -d noobsos ]; then
    ./prep-noobs-image.py
else
    echo "  [SKIPPING BUILDING NOOBSOS]"
fi

echo "[SETTING UP NOOBS]"
if [ ! -d sdcard ]; then
    mkdir sdcard
fi
if [ ! -d sdcard/os ]; then
    unzip -d sdcard NOOBS_lite_*.zip
else
    echo "  [SKIPPING NOOBS]"
fi

echo "[SETTING UP SILENTINSTALL]"
if ! grep silentinstall sdcard/recovery.cmdline > /dev/null; then
    sed -i 's/elevator=deadline/elevator=deadline silentinstall/' sdcard/recovery.cmdline
else
    echo "  [SKIPPING SILENTINSTALL]"
fi

echo "[INSTALLING NOOBSOS]"
if [ ! sdcard/os/Gentoo ]; then
    cp -a noobsos sdcard/os/Gentoo
else
    echo "  [SKIPPING INSTALLING NOOBSOS]"
fi

echo "[DONE, RUN mksdcard.sh TO MAKE THE CARD]"
