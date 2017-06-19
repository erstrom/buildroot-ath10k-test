#! /bin/bash

SCRIPT_PATH=`readlink -f $0`
SCRIPT_DIR=`dirname $SCRIPT_PATH`
BR_TOP_DIR=`readlink -f $SCRIPT_DIR/../..`
ZIMAGE=$BR_TOP_DIR/output/images/bzImage
INITRD=$BR_TOP_DIR/output/images/rootfs.cpio
QEMU=qemu-system-x86_64

# The "-device vfio-pci,host=01:00.0" line might need to be changed
# depending on IOMMU configuration.
$QEMU -cpu host,kvm=off \
-m 1024 \
--enable-kvm \
-kernel $ZIMAGE \
-initrd $INITRD \
-device vfio-pci,host=01:00.0 \
-append "console=ttyS0 debug" \
-nographic
