#!/usr/bin/env python

import json
import math
import os
import re
import subprocess
import shutil

NOOBS_DIR = "noobsos"
SLIDES_DIR = os.path.join(NOOBS_DIR, "slides_vga")
OS_FILE = os.path.join(NOOBS_DIR, "os.json")
PARTITIONS_FILE = os.path.join(NOOBS_DIR, "partitions.json")
PARTITIONS_SETUP_FILE = os.path.join(NOOBS_DIR, "partition_setup.sh")
IMAGE_FILE = os.path.join(NOOBS_DIR, "Gentoo.png")

BOOT_PATH = "staging/boot"
ROOT_PATH = "staging"

BOOT_TAR = "boot.tar.xz"
ROOT_TAR = "root.tar.xz"

partitions_json = {
    "partitions":   [
        {
            "label":                        "boot",
            "filesystem_type":              "FAT",
            "partition_size_nominal":       100,
            "want_maximised":               True,
            "uncompressed_tarball_size":    26,
            "mkfs_options": "-F 32"
        },
        {
            "label":                        "root",
            "filesystem_type":              "ext4",
            "partition_size_nominal":       2500,
            "want_maximised":               True,
            "mkfs_options":                 "-c -O ^has_journal -T small",
            "uncompressed_tarball_size":    1759
        }
    ]
}

os_json = {
    "name":     "Gentoo",
    "url":          "https://github.com/jcpetkovich/raspberrypi-2-gentoo",
    "version":      "20150611",
    "release_date": "2015-06-11",
    "kernel":       "3.18.14 3.18.14-v7",
    "description":  "Gentoo Linux for the RPI",
    "username":     "root",
    "password":     "root"
}

partition_setup = """
#!/bin/bash

# NOOBS partition setup script for Gentoo Linux ARM
#  - part1 == boot partition (FAT), part2 == root partitions (ext4)
#  - example usage:
#    part1=/dev/mmcblk0p7 part2=/dev/mmcblk0p8 ./partition_setup.sh

# extract and set part1 and part2 variables

if [[ ${part1} ==  || ${part2} ==  ]]; then
  echo "error: part1 and part2 not specified"
  exit 1
fi

# create mount points
mkdir /tmp/1
mkdir /tmp/2

# mount partitions
mount ${part1} /tmp/1
mount ${part2} /tmp/2

# adjust files
sed -ie "s|@ROOT@|${part2}|" /tmp/1/cmdline.txt
sed -ie "s|@BOOT@|${part1}|" /tmp/2/etc/fstab

# clean up
umount /tmp/1
umount /tmp/2
"""

# PREP
print("  {NOOBS SETUP}")
if not os.path.exists(NOOBS_DIR):
    os.mkdir(NOOBS_DIR)

# GET SIZES
print("  {UPDATING METADATA}")
boot = subprocess.check_output("du -s {path}".format(path = BOOT_PATH), shell = True).strip()
root = subprocess.check_output("du -s {path}".format(path = ROOT_PATH), shell = True).strip()

BOOT_SIZE = int(boot) / 1024.0
ROOT_SIZE = int(root) / 1024.0

# SOME EXTRA SPACE
BOOT_NOMINAL = math.ceil(BOOT_SIZE / 100.0) * 100
ROOT_NOMINAL = math.ceil(ROOT_SIZE / 1000.0) * 1000 + 500

partitions_json['partitions'][0]['partition_size_nominal'] = BOOT_NOMINAL
partitions_json['partitions'][0]['uncompressed_tarball_size'] = BOOT_SIZE
partitions_json['partitions'][1]['partition_size_nominal'] = BOOT_NOMINAL
partitions_json['partitions'][1]['uncompressed_tarball_size'] = BOOT_SIZE

# SET OS PARAMS
stage_file = [path for path in os.listdir('.') if 'stage3' in path][0]
release_date = re.search(r"hardfp-(.*)\.tar\.bz2", stage_file).group(1)
os_json["version"] = release_date
os_json["release_date"] = release_date[0:4] + '-' + release_date[4:6] + '-' + release_date[6:8]

# LETS WRITE
print("  {MAKING NOOBSOS}")
os.mkdir(SLIDES_DIR)
with open(PARTITIONS_SETUP_FILE, "w") as psf:
    psf.write(partition_setup)

with open(PARTITIONS_FILE, "w") as p:
    json.dump(partitions_json, p)

with open(OS_FILE, "w") as o:
    json.dump(os_json, o)

shutil.copy("Gentoo.png", IMAGE_FILE)
shutil.move(BOOT_PATH, "boot")

subprocess.check_output("tar cavf {archive} -C {path}".format(
    archive = os.path.join(NOOBS_DIR, BOOT_TAR),
    path = "boot"
), shell = True)
subprocess.check_output("tar cavf {archive} -C {path}".format(
    archive = os.path.join(NOOBS_DIR, ROOT_TAR),
    path = ROOT_PATH
), shell = True)

print("  {NOOBS DONE}")
