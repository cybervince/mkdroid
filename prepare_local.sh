#!/bin/bash

working_directory='build/WORKING_DIRECTORY'
local_sd='local_sd'

[ -d "$local_sd" ] && rm -rf "$local_sd"
mkdir -p "$local_sd/boot"
mkdir -p "$local_sd/system"

# boot
echo -e '\n Copie des fichiers de boot...'
cp -r $working_directory/device/brcm/rpi3/boot/* $local_sd/boot/
cp $working_directory/kernel/rpi/arch/arm/boot/zImage $local_sd/boot/
cp $working_directory/kernel/rpi/arch/arm/boot/dts/bcm2710-rpi-3-b.dtb $local_sd/boot/
mkdir $local_sd/boot/overlays
cp $working_directory/kernel/rpi/arch/arm/boot/dts/overlays/vc4-kms-v3d.dtbo $local_sd/boot/overlays/
cp $working_directory/out/target/product/rpi3/ramdisk.img $local_sd/boot/

# system
echo -e '\n Copie de l image du système...'
cp $working_directory/out/target/product/rpi3/system.img $local_sd/system/

echo -e "\n Environement $local_sd créé à partir de $working_directory"
