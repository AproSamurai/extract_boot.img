#!/bin/bash

# Script to extract boot.img from an EpicMTD
# Author: zman0900

# Some code for extracting zImage copied with modifications from 
# kernel_repack_utils by supercurio
# https://github.com/project-voodoo/kernel_repack_utils

# Read options
while getopts "b:o:" opt
do
    case "$opt" in
        b) boot=`readlink -f "$OPTARG"`;;
        o) out=`readlink -f "$OPTARG"`;;
    esac
done

# Check options
if [ ! -f "$boot" ]; then
    echo "Specify a boot.img with -b"
    exit 1
fi

if [ ! -n "$out" ]; then
    echo "Specify a destination directory with -o"
    exit 1
fi

# Create output file
mkdir -p $out

# Reads header from file
#BOOT_IMAGE_OFFSETS
#boot_offset=xx;boot_len=xx;recovery_offset=xx;recovery_len=xx;
eval $(grep -a -m 1 -A 1 BOOT_IMAGE_OFFSETS $boot | tail -n 1)

# Leave out 512 byte header between zImage and boot
zimage_len=$(($boot_offset-1))

# Display info
echo "Boot image extracter for EpicMTD"
echo "Author: zman0900"
echo
echo "boot.img info:"
echo "zImage offset = 0"
echo "zImage length = "$zimage_len
echo "Boot offset = "$boot_offset
echo "Boot length = "$boot_len
echo "Recovery offset = "$recovery_offset
echo "Recovery length = "$recovery_len

# Split images
echo
echo "Splitting images..."
dd if=$boot skip=0 count=$zimage_len of=$out/zImage >& /dev/null
dd if=$boot skip=$boot_offset count=$boot_len of=$out/boot.cpio.gz >& /dev/null
dd if=$boot skip=$recovery_offset count=$recovery_len of=$out/recovery.cpio.gz >& /dev/null

# Split initramfs from zImage
echo "Finding initramfs..."
pos=`grep -P -a -b --only-matching '\x1F\x8B\x08' $out/zImage | cut -f 1 -d : | grep '1' | awk '(NR==1)'`
dd if=$out/zImage bs=$pos skip=1 2> /dev/null | gunzip > $out/initramfs.dat 2> /dev/null
start=`grep -a -b --only-matching '070701' $out/initramfs.dat | head -1 | cut -f 1 -d :`
end=`grep -a -b --only-matching 'TRAILER!!!' $out/initramfs.dat | head -1 | cut -f 1 -d :`
end=$((end + 10))
count=$((end - start))
echo "Spliting initramfs from zImage..."
dd if=$out/initramfs.dat ibs=$start skip=1 of=$out/temp >& /dev/null
dd if=$out/temp bs=$count count=1 of=$out/initramfs.cpio >& /dev/null
rm $out/temp $out/initramfs.dat

# Extract cpio files
echo "Extracting cpio files..."
mkdir $out/{boot,recovery,initramfs}
cd $out/boot
zcat $out/boot.cpio.gz | cpio -i --no-absolute-filenames >& /dev/null
cd $out/recovery
zcat $out/recovery.cpio.gz | cpio -i --no-absolute-filenames >& /dev/null
cd $out/initramfs
cpio -i --no-absolute-filenames < $out/initramfs.cpio >& /dev/null

# Deleting initramfs.cpio since it isn't quite a valid cpio
rm $out/initramfs.cpio
echo "Done"
