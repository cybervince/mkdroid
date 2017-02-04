#!/bin/bash

# Package par défaut si lancé sans argument
default_gapps_pkg='gapps/open_gapps-arm-7.1-tvstock-20170201.zip'


[ -z $1 ] && gapps_pkg=$default_gapps_pkg || gapps_pkg=$1
[ ! `which lzip` ] && echo 'lzip introuvable, veuillez installer lzip' && exit 1
[ ! `which rsync` ] && echo 'rsync introuvable, veuillez installer rsync' && exit 1
[ ! -f "$gapps_pkg" ] && echo "Package $gapps_pkg introuvable" && exit 1
workdir=`dirname $gapps_pkg`
[ -d "$workdir/pkg" ] && rm -rf pkg

echo " * Extraction du package Gapps $gapps_pkg..."
unzip "$gapps_pkg" -d "$workdir/pkg" &> /dev/null

rm -rf $workdir/tmp > /dev/null 2>&1
mkdir -p $workdir/tmp

echo -e "\n * Extraction des packages contenus dans $gapps_pkg..."
find $workdir -name "*.tar.?z" -exec tar -xf {} -C $workdir/tmp/ \;

echo -e "\n * Préparation de la partition systeme locale"
rm -rf $workdir/system > /dev/null 2>&1
mkdir -p $workdir/system
for dir in $workdir/tmp/*/
do
  pkg=${dir%*/}
  dpi=$(ls -1 $pkg | head -1)

  echo "  - including $pkg/$dpi"
  rsync -aq $pkg/$dpi/ $workdir/system/
done

rm -rf $workdir/tmp $workdir/pkg

echo -e "\n * Gapps disponibles dans le répertoire $workdir/system"
