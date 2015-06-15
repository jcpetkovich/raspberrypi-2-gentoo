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
    sudo tar xaf stage3-armv7a_hardfp-*.tar.bz2 -C staging
    sudo tar xaf portage-latest.tar.bz2 -C staging/usr/
else
    echo "  [SKIPPING BASIC ROOTFS SETUP]"
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
    sudo mkdir -p staging/usr/doc
    sudo cp -a firmware/documentation staging/usr/doc/libraspberrypi-doc
else
    echo "  [SKIPPING OPTIONAL SOFTWARE]"
fi


echo "[BUILDING KERNEL]"
if [ ! -f linux/arch/arm/boot/zImage ]; then

    pushd linux > /dev/null
    if [ ! -f .config ]; then
        make mrproper
        make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- bcm2709_defconfig
    fi
    make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- menuconfig
    make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- -j5
    make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- -j5 modules
    popd > /dev/null
else
    echo "  [SKIPPING KERNEL]"
fi

echo "[INSTALLING KERNEL]"
pushd linux > /dev/null
sudo make ARCH=arm CROSS_COMPILE=${TARGET_CHOST}- INSTALL_MOD_PATH=../staging modules_install > /dev/null
popd > /dev/null
sudo cp linux/arch/arm/boot/zImage staging/boot/kernel7.img

echo "[SETTING EMPTY ROOT PASSWORD (change asap)]"
sudo sed -i "s/root:\*:/root::/" staging/etc/shadow

echo "[CONFIGURING PORTAGE (never skips, need root)]"
cat <<EOF | sudo tee staging/var/lib/portage/world > /dev/null
app-misc/screen
app-portage/eix
app-portage/genlop
app-portage/gentoolkit
app-portage/layman
sys-apps/usbutils
EOF

cat <<EOF | sudo tee staging/etc/portage/make.conf > /dev/null
# CFLAGS Optimized for numerical computatins on the rpi2
CFLAGS="-O2 -pipe -march=armv7-a -mfpu=vfp -mfloat-abi=hard -mcpu=cortex-a7 -mtune=cortex-a7"
CXXFLAGS="${CFLAGS}"
CHOST="armv7a-hardfloat-linux-gnueabi"

# nss because of apache/nginx
USE="bindist nss"

# Decent Python targets
PYTHON_TARGETS="$PYTHON_TARGETS python3_4"
USE_PYTHON="2.7 3.3"

PORTDIR="/usr/portage"
DISTDIR="${PORTDIR}/distfiles"
PKGDIR="${PORTDIR}/packages"

# DISTCC, ADJUST FOR YOUR OWN NUM CORES
MAKEOPTS="-j10 -l1"
FEATURES="distcc"
EOF

cat <<EOF | sudo tee staging/boot/cmdline.txt > /dev/null
ipv6.disable=1 avoid_safe_mode=1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=@ROOT@ rootfstype=ext4 elevator=noop rootwait
EOF

echo "[CONFIGURING INITTAB]"
if ! grep ttyAMA0 staging/etc/inittab > /dev/null 2>&1; then
    sudo sed -i 's/9600 ttyS0/115200 ttyAMA0/' staging/etc/inittab
fi

echo "[SETTING UP INTERNET]"
if ! grep dhcp staging/etc/conf.d/net > /dev/null 2>&1; then
    cat <<EOF | sudo tee staging/etc/conf.d/net > /dev/null
config_eth0="dhcp"
EOF
    pushd staging/etc/init.d > /dev/null
    sudo ln -s net.lo net.eth0
    popd > /dev/null

    pushd staging/etc/runlevels/default > /dev/null
    sudo ln -s /etc/init.d/net.eth0 net.eth0
    sudo ln -s /etc/init.d/sshd     sshd
    popd > /dev/null
else
    echo "  [SKIPPING INTERNET]"
fi

echo "[BUILDING NOOBSOS]"
if [ ! -d noobsos ]; then
    ./prep-noobs-image.py
    sudo chown root:root -R noobsos
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
if [ ! -d sdcard/os/Gentoo ]; then
    cp -a noobsos sdcard/os/Gentoo
else
    echo "  [SKIPPING INSTALLING NOOBSOS]"
fi

echo "[DONE, RUN mksdcard.sh TO MAKE THE CARD]"
