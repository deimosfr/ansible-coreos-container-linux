#!/bin/bash

iso=coreos_production_iso_image.iso

# Check if image has already been patched
if [ -f $iso.orig ] ; then
  echo "Image already patched"
  exit 0
fi

# Ensure required binaries are present
for binary in 'sudo' 'osirrox' 'gunzip' 'cpio' 'unsquashfs' 'mksquashfs' 'gzip' 'genisoimage' ; do
  echo "Check if $binary exists or exit..."
  which $binary 1>/dev/null || exit 1
done

# Flush old data
sudo rm -Rf cd
mkdir cd

# Extract iso
osirrox -indev $iso -extract / cd
chmod -Rf u+w cd

# Unzip squashfs
cd ./cd/coreos
gunzip cpio.gz
cpio -i < cpio
sudo unsquashfs usr.squashfs

# Add ssh key to CoreOS
sudo mkdir squashfs-root/share/skel/.ssh
sudo cp ~/.ssh/id_rsa.pub squashfs-root/share/skel/.ssh/authorized_keys
sudo sh -c 'echo "L /home/core/.ssh/authorized_keys - core core - ../../../usr/share/skel/.ssh/authorized_keys" >> squashfs-root/lib64/tmpfiles.d/baselayout-home.conf'
sudo sh -c 'echo "StrictModes no" >> squashfs-root/share/ssh/sshd_config'

# Make sqashfs
rm -f usr.squashfs
sudo mksquashfs squashfs-root usr.squashfs -noappend -always-use-fragments
sudo rm -Rf etc squashfs-root
find usr.squashfs | cpio -o -A -H newc -O cpio
sudo rm -f usr.squashfs
gzip -9 cpio
cd ..

# Make ISO image and clean
if [ ! -f ../$iso.orig ] ; then
  mv ../$iso ../$iso.orig
fi
genisoimage -o ../$iso -r -J -no-emul-boot -z -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat ../cd || exit 1
cd ..
sudo rm -Rf cd
