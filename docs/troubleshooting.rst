Troubleshooting
---------------

CoreOS VM Does Not Boot
~~~~~~~~~~~~~~~~~~~~~~~
A failure to boot the CoreOS VM usually appears as a message in the start
terminal saying the VM IP address cannot be determined.

::

    > booting rktmachine (1/1)
    [ERROR] Unable to grab VM's IP after 30s (!)... Aborted

    Press [Enter] to continue.

First try the troubleshooting advice from Corectl_.

.. _Corectl: https://github.com/TheNewNormal/corectl

- Check your macOS machine is running Yosemite 10.10.3 or later.
- The macOS machine must also be a 2010 or later model so that the CPU supports
  the EPT_ extensions.
- VirtualBox not installed or newer than version 4.3.30. This is incompatible
  with the xhyve_ underlying Hypervisor and can cause a kernel panic if run
  simultaneously with an old VirtualBox or if the VirtualBox has been run since
  the last reboot.
- Ensure any running desktop firewalls, e.g. ESET, Little Snitch, are not
  disallowing traffic from/to the ``bridge100`` interface used by the CoreOS
  VM. This will prevent the VM from booting since it will not be able to fetch
  cloud-init or other configuration data from the host machine.

.. _EPT: https://en.wikipedia.org/wiki/Second_Level_Address_Translation#EPT
.. _xhyve: https://github.com/mist64/xhyve


Otherwise, look in the ``~/.coreos`` directory for VM boot log files. For
RktMachine, they will be in
``~/.coreos/running/C16CF576-FB07-4DC9-8BF6-C022445B31A8/log``. This file
will contain error messaging for boot failures on the VM.

To try a complete reset, make sure to delete ``~/.rktmachine``, remove the
RktMachine application, and to reboot the host macOS machine to reset any
issues in virtualisation.


NFS Mount Unavailable
~~~~~~~~~~~~~~~~~~~~~
The NFS ``/Users`` directory is loaded late on VM boot. So if you have SSH-ed
to the instance immediately on boot then the directory may be unavailable until
the later boot sequence services are started.

The NFS mount will become available after a few moments when the boot has
completed.

This is particularly noticeable if you create convenience symlinks from the
home directory in the CoreOS VM to checked out development repositories in the
NFS mount. These are useful to switch quickly to working off locations on the
host drive.


NFS Mount Not Writable
~~~~~~~~~~~~~~~~~~~~~~
The NFS ``/Users`` directory is not writable as the default CoreOS VM user. So
when SSH-ed onto the CoreOS VM, it is often necessary to copy or move files
onto the ``/Users`` mount as root instead. This is because the default user on
the CoreOS VM has a user id that is unlikely to match the user id of the host
machine user which is needed for NFS permissions to be satisfied.

This is less of an issue when writing to ``/Users`` if it is mounted as a
volume in a running container. This is because the user under which a container
is run is typically root already.


Reclaiming VM Root Disk Image Space
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The underlying ``/`` storage on the CoreOS VM is provided by a QEMU
Copy-on-write format file in ``~/.rktmachine/root.qcow2``. This is a sparse
image file with a maximum size of 40Gb.

Over time this file grows with CoreOS VM use, e.g. new rkt containers and
builds. In the worst case this will fill the maximum allocation and result in
``No space left on device`` errors.

The sparse image file does not automatically reduce in size, so even though you
may free up space on the image it may not be reflected in the actual size of
the image on the host device.

To see the current size of the root image disk, use:

::

    $ du -sh ~/.rktmachine/root.qcow2
    2.5G	/Users/docrualaoich/.rktmachine/root.qcow2

To reduce this first free up space on the image from a terminal on the CoreOS
VM, e.g. by running sudo rkt gc, sudo rkt image gc, removing large files in the
user home directory.

Then, from the host machine, follow these instructions on how to
`Shrink Qcow2 Disk Files`_.

.. _Shrink Qcow2 Disk Files: https://pve.proxmox.com/wiki/Shrink_Qcow2_Disk_Files

This sequence of actions requires QEMU_ to be installed on your macOS machine.
The easiest installation is using the Homebrew_ package manager. First install
that using the instructions on the Homebrew site and then run:

.. _QEMU: http://www.qemu.org
.. _Homebrew: https://brew.sh

::

    brew install qemu

Once the preliminaries are complete, begin by stopping any running CoreOS VM
using the RktMachine menubar options.

Change to the ``~/.rktmachine`` working directory for RktMachine and move the
current root disk image to a backup.

::

    cd ~/.rktmachine
    mv root.qcow2 root.qcow2_backup

Then use the QEMU image tool to make a new root image from the backup. By
specifying the same sparse image type in the ``-O`` type argument, the
conversion will optimise the image as a side effect.

::

    qemu-img convert -O qcow2 root.qcow2_backup root.qcow2

The new image size can be checked and compared against the pre-shrink image:

::

    du -sh root.qcow2*

Restart the CoreOS VM using the RktMachine menu and verify that the root image
functions correctly, i.e. the VM boots and contains the same rkt containers and
user home directory files as previously.

Remove the ``root.qcow2_backup`` image when you are happy that the new image
file is not corrupt.
