#!/bin/bash

sdcard=$1
boot_size=512
system_size=4096
cache_size=1024
userdata_size=100%

local_sd="local_sd"


function umount_sd
{
  while read mounted_part
  do
    umount $mounted_part & > /dev/null
  done < <(mount | grep ${sdcard} | cut -d' ' -f1)

}

function create_partitions
{
  umount_sd

  echo -e "\n Création de la table de partitions sur ${sdcard}" | tee
  parted ${sdcard} -s mktable msdos &> /dev/null
  sync
  partprobe

  echo -e "\n Création de la parttion boot ${sdcard}1 (${boot_size})"
  parted ${sdcard} unit MiB print -s -- mkpart primary fat32 2048s `echo $((${boot_size} + 1))` &> /dev/null
  wipefs -a ${sdcard}1 &> /dev/null
  sync

  echo -e "\n Création de la parttion system ${sdcard}2 (${system_size})"
  system_part_start=`parted ${sdcard} unit MiB print -m | grep ^1 | cut -d':' -f3 | sed 's/MiB//'`
  parted ${sdcard} unit MiB print -s -- mkpart primary $system_part_start `echo $(($system_part_start + $system_size))` &> /dev/null
  wipefs -a ${sdcard}2 &> /dev/null
  sync

  echo -e "\n Création de la parttion cache ${sdcard}3 (${cache_size})"
  cache_part_start=`parted ${sdcard} unit MiB print -m | grep ^2 | cut -d':' -f3 | sed 's/MiB//'`
  parted ${sdcard} unit MiB print -s -- mkpart primary $cache_part_start `echo $(($cache_part_start + $cache_size))` &> /dev/null
  wipefs -a ${sdcard}3 &> /dev/null
  sync

  echo -e "\n Création de la parttion userdata ${sdcard}4 (${userdata_size})"
  userdata_part_start=`parted ${sdcard} unit MiB print -m | grep ^3 | cut -d':' -f3 | sed 's/MiB//'`
  parted ${sdcard} unit MiB print -s -- mkpart primary $userdata_part_start $userdata_size &> /dev/null
  wipefs -a ${sdcard}4 &> /dev/null
  sync

  [ ${FUNCNAME[1]} == "menu" ] && menu

}

function format_boot
{
  umount ${sdcard}1 &> /dev/null
  echo -e "\n Formattage de boot..."
  mkfs.vfat -F32 -n "boot" ${sdcard}1 &> /dev/null
  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function format_system
{
  umount ${sdcard}2 &> /dev/null
  echo -e "\n Formattage de system..."
  mkfs.ext4 -F -L "system" ${sdcard}2 &> /dev/null
  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function format_cache
{
  umount ${sdcard}3 &> /dev/null
  echo -e "\n Formattage de cache..."
  mkfs.ext4 -F -L "cache" ${sdcard}3 &> /dev/null
  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function format_userdata
{
  umount ${sdcard}4 &> /dev/null
  echo -e "\n Formattage de userdata..."
  mkfs.ext4 -F -L "userdata" ${sdcard}4 &> /dev/null
  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function install_boot
{
  echo -e "\n Preparation de la partition de boot..."
  mkdir mnt &> /dev/null
  mount ${sdcard}1 mnt
  cp -r $local_sd/boot/* mnt
  sync
  umount ${sdcard}1
  rm -rf mnt
  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function install_system
{
  echo -e "\n Ecriture du systeme..."
  dd if=$local_sd/system/system.img of=${sdcard}2 bs=1M &> /dev/null

  echo -e "\n Redimensionnement du filesystem system..."
  e2fsck -f -y ${sdcard}2 &> /dev/null
  resize2fs ${sdcard}2 &> /dev/null
  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function install_optionnals
{
  echo -e '\n Installation des composants optionnels...'
  umount_sd
  mkdir -p mnt/optionnals/system &> /dev/null
  mount ${sdcard}2 mnt/optionnals/system

  while read optfile
  do
    if [ -f $optfile ]
    then
      echo -e "\t -> `basename $optfile`"
      [ ! -d "mnt/`dirname $optfile`" ] | mkdir -p mnt/`dirname $optfile`
      cp -rf $optfile mnt/$optfile
      chmod a+r $optfile
    fi
  done < <(find optionnals/system/ -type f) 
  
  sync
  umount ${sdcard}2
  rm -rf mnt

  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function format_all
{
  format_boot
  format_system
  format_cache
  format_userdata
  [ ${FUNCNAME[1]} == "menu" ] && menu
}

function install_android
{
  umount_sd
  create_partitions
  format_all
  install_boot
  install_system
  install_optionnals
  umount_sd
  echo -e '\nFini !\n'
}

function banner {
  clear
  echo ' ---------------------------------------------------'
  echo ''
  echo '                  ** MkDroid **'
  echo ''
  echo "       - $1 -"
  echo ''
  echo ' ---------------------------------------------------'
  echo ''
}

function choix_sd
{
  banner "Choix de la cible"
  echo -n 'Sur quelle carte SD voulez-vous installer Android ? '
  read sdcard
  [ -z $sdcard ] && choix_sd
}

function menu
{
  banner "Cible: ${sdcard} [${sd_name}]"
  echo -e "1 - Installer Android sur ${sdcard} automatiquement\n"
  echo -e '\nTâches unitaires:'
  echo -e '\n     * Partitionement *'
  echo "2 - Créer les partitions sur ${sdcard}"
  echo -e '\n     * Formattage *'
  echo "3 - Formatter toutes les partitions sur ${sdcard}"
  echo "4 - Formatter la partition boot (${sdcard}1)"
  echo "5 - Formatter la partition system (${sdcard}2)"
  echo "6 - Formatter la partition cache (${sdcard}3)"
  echo "7 - Formatter la partition userdata (${sdcard}4)"
  echo -e '\n     * Installation *'
  echo "8 - Installer la partition boot sur ${sdcard}1"
  echo "9 - Installer la partition system sur ${sdcard}2"
  echo "10 - Installer les composants optionnels"
  echo -e '\n\nO - Quitter'
  echo -e '\n'
  
  choix

  case $action in
    1)  confirm "ATTENTION: Toutes les données sur ${sdcard} [${sd_name}] seront détruites !\nInstaller Android sur ${sdcard} ?" && install_android || menu ;;
    2)  confirm "Créer les partitions sur ${sdcard} ?" && create_partitions || menu ;;
    3)  confirm "Formatter toutes les partitions sur ${sdcard} ? " && format_all || menu;;
    4)  confirm "Formatter la partition boot (${sdcard}1) ?" && format_boot || menu ;;
    5)  confirm "Formatter la partition system (${sdcard}2) ?" && format_system || menu ;;
    6)  confirm "Formatter la partition cache (${sdcard}3) ?" && format_cache || menu ;;
    7)  confirm "Formatter la partition userdata (${sdcard}4) ?" && format_userdata || menu ;;
    8)  confirm "Installer la partition boot sur ${sdcard}1 ?" && install_boot || menu ;;
    9)  confirm "Installer la partition system sur ${sdcard}2 ?" && install_system || menu ;;
    10)  confirm "Installer les composants optionnels ?" && install_optionnals || menu ;;
    0)  exit 0
  esac
}

function choix
{
  echo -n 'Votre choix: '
  read action
  [ -z `echo "$action" | grep -E ^\-?[0-9]+$` ] && menu
}

function confirm
{
  echo -en "\n$1 (o/N): "
  read reponse
  case $reponse in
    O*|o*)  return 0 ;;
    *) return 1 ;;
  esac
}


# Programme principal

[ -z $sdcard ] && choix_sd
[ ! `id -u` -eq 0 ] && echo 'Veuillez lancer ce script en root, ou bien via sudo' && exit 1

sd_name=`parted ${sdcard} unit MB print -m | grep ${sdcard} | cut -d':' -f7`
menu
