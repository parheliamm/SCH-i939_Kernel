#!/bin/sh
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/ramdisk`
export USE_SEC_FIPS_MODE=true

if [ "${1}" != "" ];then
  export KERNELDIR=`readlink -f ${1}`
fi

mkdir -p /home/bsquare/temp/tmp/ramfs-source-sgs3
RAMFS_TMP="/home/bsquare/temp/tmp/ramfs-source-sgs3"

. $KERNELDIR/.config

echo "...............................................................Compiling modules.............................................................."
cd $KERNELDIR/
make -j8 || exit 1

echo "................................................................Updating ramdisk.............................................................."
#remove previous ramfs files
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
rm -rf $RAMFS_TMP.cpio.gz
#copy ramfs files to tmp directory
cp -ax $RAMFS_SOURCE $RAMFS_TMP
#clear git repositories in ramfs
find $RAMFS_TMP -name .git -exec rm -rf {} \;
#remove empty directory placeholders
find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
rm -rf $RAMFS_TMP/tmp/*
#remove mercurial repository
rm -rf $RAMFS_TMP/.hg
#copy modules into ramfs
mkdir -p $RAMFS_TMP/lib/modules
find -name '*.ko' -exec cp -av {} $RAMFS_TMP/lib/modules/ \;
/home/bsquare/cyanogenmod10/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-strip --strip-unneeded $RAMFS_TMP/lib/modules/*

echo ".............................................................Building new ramdisk............................................................."
cd $RAMFS_TMP
find | fakeroot cpio -H newc -o > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
gzip -9 $RAMFS_TMP.cpio

echo "...............................................................Compiling kernel..............................................................."
cd $KERNELDIR
make -j8 zImage || exit 1

echo ".............................................................Making new boot image............................................................"
./mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --board smdk4x12 --base 0x10000000 --pagesize 2048 --ramdiskaddr 0x11000000 -o $KERNELDIR/boot.img

echo ".............................................................Create tar ball ............................................................"
tar cvf boot.tar boot.img
md5sum -t boot.tar >> boot.tar
mv boot.tar boot.tar.md5
echo ".....................................................................done....................................................................."
