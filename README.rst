ath10k + buildroot + QEMU
=========================

This repository is a fork of buildroot (https://buildroot.org/) intended
to be used as a QEMU based test environment for ath10k.

Everything needed to build the entire system is included (directly or indirectly)
in this repository (depending packages will be fetch automatically from the
internet).

For more information about buildroot, please consult the official buildroot
documentation:

https://buildroot.org/downloads/manual/manual.html

The repo contains an x86_64 based defconfig intended to be used with QEMU:

- qemu_ath10k_x86_64_defconfig 

Build instructions
------------------

Clone the buildroot-ath10k-test git repository::

    git clone https://github.com/erstrom/buildroot-ath10k-test.git
    cd buildroot-ath10k-test

The default branch is the recommended branch to use and thus,
there is no need to checkout a custom branch.

Note that the default branch is not *master* which is normally used
as default in most git repositories.
Instead the default branch is *ath10k-qemu*.
The *master* branch will be identical to the official buildroot *master*.

To build a set of images for QEMU (kernel + initrd), issue the below commands::

    make qemu_ath10k_x86_64_defconfig
    make

The build artifacts are present in *output/images*. They are comprised of:

- bzImage
- rootfs.cpio 

rootfs.cpio contains a minimal busybox based rootfs (containing the ath10k
drivers)

Configuration
+++++++++++++

If you want to modify any settings (like changing kernel version etc.),
just run a ``make menuconfig`` and change all default settings to suite
your needs.

If you want to use wpa_supplicant to connect to your AP, you would most
likely want to create a custom *wpa_supplicant.conf* file on the target
rootfs.

The easiest way to do this is to add the *wpa_supplicant.conf* file to
the rootfs overlay directory::

	wpa_passphrase <ssid> <password> > board/qemu/x86_64/rootfs-overlay-ath10k-test/etc/wpa_supplicant.conf

The above command assumes you have an AP using WPA2 PSK security. 

QEMU
----

QEMU is an open source machine emulator and virtualizer.

See https://www.qemu.org/ for more details.

Debugging with QEMU
can be very useful if the driver is not fully stable since a kernel panic
can potentially render the entire system useless.
When using QEMU, a faulty system can easily be rebooted and a test can be
repeated over and over without having to reboot the computer.
Another nice feature with QEMU is that it offers an easy way to debug the
kernel with gdb (since it has an integrated gdb server).

QEMU and USB
++++++++++++

It is not recommended to run QEMU with root privileges, so it might
be necessary to change the permissions of the USB devices that is going to be
connected to the QEMU system.

The easiest way to change the permissions for a specific device is to add
an udev rule.

In our case, we want the USB device to be accessible (read and write) by a non
root user.

Insert the USB device into the host computer and check the dmesg log.
Below is an example:

::

	[ 5879.905517] usb 3-2: new high-speed USB device number 4 using xhci_hcd

The log message tells us that it is device number 4 on usb bus 3.

Create an udev rule for the device in ``/etc/udev/rules.d``.
For a WUSB6100M, the rule will look something like this:

::

	/etc/udev/rules.d/51-wusb6100.rules
	-----------------------------------

	SUBSYSTEMS=="usb", ACTION=="add", ATTRS{idVendor}=="13b1", ATTRS{idProduct}=="0042", MODE="0666"

Once the rule is created it is time to test it.
In order to test the udev rule, issue the below command:

::

	udevadm test $(udevadm info -q path -n /dev/bus/usb/003/004) 2>&1

The path to the usb device (*/dev/bus/usb/003/004* in the above example)
can be derived from the dmesg output. *003* is the bus number and *004*
is the device number.

Check the output and verify the rule is correct and that no other
rule is overriding it. In our case, the rule number (51) is important
since we want our rule file to override the default settings for device
nodes (we need our custom rule to be executed after *50-udev-default*) .

Once we are satisfied with the rules, they should be updated globally:

::

	udevadm control --reload

Run the custom kernel in a QEMU VM
----------------------------------

Before launching QEMU, make sure the ath10k_usb module is not loaded on
the host system. It is recommended to blacklist it if it is present on
the host.

Launch QEMU with the below command:

::

    qemu-system-x86_64 --enable-kvm \
    -kernel output/images/bzImage \
    -initrd output/images/rootfs.cpio \
    -usb \
    -device usb-ehci,id=ehci \
    -device usb-host,vendorid=0x13b1,productid=0x0042 \
    -append "console=ttyS0" \
    -nographic \
    -m 1024

*--enable-kvm* is not mandatory and requires that hardware virtualization is
enabled (Intel Vt-x). This is typically done in BIOS. Most x86 CPUs
support this feature, and since the performance benefit is substantial, the use
of it is highly recommended. 

*vendorid=0x13b1,productid=0x0042* is the vendor and product id of the
WUSB6100M.
In case you have any other ath10k USB device, make sure to update the ID 
accordingly.

*-device usb-ehci,id=ehci* is important in order to make sure QEMU creates
a virtual EHCI USB bus (using the *-usbdevice host:0x13b1:0x0042* option
will result in QEMU creating a UHCI bus instead).

Make sure QEMU has write access to the usb device. See `QEMU and USB`_ for
more details.

The above qemu call have been added in a wrapper script:

*support/scripts/run-qemu-ath10k_usb.sh*

Connect to an AP
++++++++++++++++

Once the virtual system has booted, make sure the USB device is properly
connected (use *lsusb* or similar check that the device is present).

If connected properly, load the kernel module:

::

	modprobe ath10k_usb

Make sure the network device (*wlan0* by default) has been created:

::

	ifconfig -a

To connect to an AP:

::

	wpa_supplicant -B -Dnl80211 -iwlan0 -c /etc/wpa_supplicant.conf

The above command assumes you have added your own */etc/wpa_supplicant.conf*
with the correct setup for your network.

To obtain an IP address with udhcpc (busybox dhcp client):

::

	udhcpc -i wlan0

The above procedure has been added in the below script:

*board/qemu/x86_64/rootfs-overlay-ath10k-test/usr/bin/start-ath10k.sh*

When building, this script will be copied into */usr/bin* on the target 
rootfs (inside rootfs.cpio).

Hence, in order to automatically connect to the AP specified in
*/etc/wpa_supplicant.conf*, just issue the below command::

    start-ath10k.sh 

Basic performance test using iperf
++++++++++++++++++++++++++++++++++

iperf is a tool that can be used to test network performance.

See https://iperf.fr/ for more info about the tool.

Two scripts have been added to the rootfs overlay:

- iperf-client.sh
- iperf-server.sh

Let's assume that the QEMU environment should act as a server.

In the QEMU environment, issue the below command::

    iperf-server.sh

On another computer on the network (perhaps the computer hosting
the QEMU environment), issue the below command::

    iperf -c <IP addr of QEMU> -p 1234
