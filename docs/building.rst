Building
--------

XCode
~~~~~
The macOS menu bar application is built using Xcode. To run a development build
of RktMachine, start by opening the RktMachine project file in Xcode.

::

   $ open RktMachine.xcodeproj

Make sure you are not already running RktMachine. Then use the
``Product -> Run`` menu option or the play button in the top left to build and
run the RktMachine source code.


.. _developmentrktcontainer:

Development Tools Container
~~~~~~~~~~~~~~~~~~~~~~~~~~~
The RktMachine source comes with a ``dev`` directory which contains a script
for building a rkt Ubuntu container with QEMU and other useful development
tools for RktMachine development.

To build this, start the CoreOS VM from RktMachine and SSH to it. Then copy the
``dev/dev-rktmachine.build.sh`` script from your ``/Users`` NFS mount to the
CoreOS VM.

To build and install the rkt container:

::

    ./dev-rktmachine.build.sh

Once the script is finished building and installing the container, you can
start an interactive session with the current working directory mounted inside
the container at ``/rktmachine`` by running the following.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

The container includes a build chain, Sphinx for compiling this documentation,
QEMU for working with disk images, and dependencies for building the Avahi mDNS
tool.


Rebuilding ``root.qcow2``
~~~~~~~~~~~~~~~~~~~~~~~~~
The ``root.qcow2`` image file is the base file used in new CoreOS VMs to
provide persistent storage in the user home directory and elsewhere. Since the
CoreOS VM initialisation formats the root image if necessary, this image file
only needs to be the right size. In particular, we do not need to create a
filesystem on the image.

In this section, we detail how to create the ``root.qcow2`` image file to
include under ``src/vm/root.qcow2`` in case there is a need to rebuild it, e.g.
to set a new default image size.

As in the previous section, SSH to the CoreOS VM and install the
``dev-rktmachine`` container image if not already available. Then start the
container as before.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

Once in an interactive session on the container, change to the ``/rktmachine``
directory so output will be on the mounted directory and available to the
CoreOS VM after the container is stopped.

Then run the ``qemu-img`` command to create the qcow2 disk image file. Finally,
exit the container.

::

    cd /rktmachine
    qemu-img create -f qcow2 root.qcow2 40G
    exit

Once back on the CoreOS VM, the ``root.qcow2`` file will be present in the
current directory. The easiest way to copy the image file to the host macOS
machine is to copy it to the NFS mounted ``/Users`` directory on the CoreOS VM.


Rebuilding ``tools.qcow2``
~~~~~~~~~~~~~~~~~~~~~~~~~~
The ``tools.qcow2`` image file contains binaries needed for VM setup which are
too large to be delivered by Cloud Init. Specifically, it contains:

- The `acbuild` binaries for building new container images on the CoreOS VM.
- A statically linked ``avahid`` for broadcasting mDNS from the CoreOS VM so
  it can be addressed as ``rktmachine.local`` instead of by IP address.

Building this image file is more involved since we need to change from the
container to the VM a number of times. This is because some operations need to
be performed on the contents of the filesystem which is easiest to work with
when mounted to a container. Other operations on the image file itself are more
convenient from the CoreOS VM with access to the ``tools.qcow2`` file itself.

As in the previous section, SSH to the CoreOS VM and install the
``dev-rktmachine`` container image if not already available. Then start the
container as before.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

Once in an interactive session on the container, change to the ``/rktmachine``
directory so output will be on the mounted directory and available to the
CoreOS VM after the container is stopped.

But this time create a raw image file instead of a qcow2 image file because raw
images are easier to mount. Later, we will convert the raw image to qcow2
format when we are finished creating it.

::

    cd /rktmachine
    qemu-img create -f raw tools.raw 1G

Now exit the container and format the image file as an ext4 filesystem.

::

    sudo /sbin/mkfs.ext4 -i 8192 -L tools -F tools.raw

Next, mount the ``tools.raw`` image file to the CoreOS VM. This is an easy way
to also make it available to containers.

::

    mkdir tools
    sudo mount -o loop tools.raw tools

Install the ``acbuild`` binaries by downloading them from the
`acbuild GitHub repository`_ and copying them to the ``tools`` directory.

.. _acbuild GitHub repository: https://github.com/containers/build

::

    wget https://github.com/containers/build/releases/download/v0.4.0/acbuild-v0.4.0.tar.gz
    sudo tar xzvf acbuild-v0.4.0.tar.gz -C tools --strip-components=1
    sudo chmod u+s tools/acbuild

Adding Avahi_ is a more difficult process since it is not provided as a
statically linked binary. Instead we have to get the source and attempt to
build it so that it can be run on the CoreOS VM. There are a number of warnings
and cautions in the following steps but the produced binary appears to work.

.. _Avahi: http://www.avahi.org

We need to build statically linked binaries because the bare CoreOS VM that we
aim to run it on does not have all the necessary dynamic libraries available.

Since CoreOS does not have a build chain, we need to reenter the container and
build Avahi there. Change to the ``/rktmachine`` directory as before.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

    cd /rktmachine

Start by downloading the Avahi source.

::

    wget https://github.com/lathiat/avahi/archive/v0.6.32.tar.gz
    tar xzvf v0.6.32.tar.gz
    pushd avahi-0.6.32 > /dev/null

Use Autoconf/Automake to create a ``./configure`` file.

::

    ./autogen.sh
    autoreconf -i
    automake --add-missing

Now for a ridiculous hack. It is significant effort to make these build files
link to the static version of ``libdaemon``. Instead, we encourage it strongly
to do so by deleting the dynamic version of ``libdaemon``. Let's see it link
dynamically after that.

::

    rm /usr/lib/x86_64-linux-gnu/libdaemon.so

Build ``avahi`` with a set of options that turns nearly everything off.

::

    CONFIGURE_OPT="
            --prefix=`pwd`/../install
            --disable-shared
            --disable-glib --disable-gobject
            --disable-qt3 --disable-qt4
            --disable-gtk --disable-gtk3
            --disable-gdbm
            --disable-python --disable-pygtk --disable-python-dbus
            --disable-mono --disable-monodoc
            --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html
            --disable-doxygen-xml
            --disable-manpages --disable-xmltoman
            --disable-dbus
            --with-distro=none
            --with-avahi-user=root
            --with-avahi-group=daemon
            --localstatedir=/var
            "

    ./configure ${CONFIGURE_OPT}
    make clean install

All going well, the build artifacts will be in ``/rktmachine/install``. The
binary we want is ``avahid`` so copy that to the ``tools`` directory.

::

    popd > /dev/null
    cp install/sbin/avahi-daemon tools

Exit the container and unmount the image file.

::

    sudo umount tools

Finally restart the container and do the file conversion to create a qcow2
format image from the raw image file.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

    cd /rktmachine
    qemu-img convert -f raw -O qcow2 tools.raw tools.qcow2
    exit

Copy the ``tools.qcow2`` image to where it is needed, typically to the
RktMachine repository under ``src/vm/tools.qcow2``. As before, the easiest way
to copy the image file to the host machine is to copy it to the NFS mounted
user directory on the CoreOS VM.


Rebuilding macOS Corectl Binaries
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The latest versions of the Corectl binaries can be downloaded from the
`Corectl releases`_ for inclusion in the RktMachine application.

.. _Corectl releases: https://github.com/TheNewNormal/corectl/releases

Alternatively the Corectl binaries can be built from source, e.g. to test
changes or for debugging purposes.

Since the Corectl binaries are run on the host macOS machine, it is more
convenient to build on macOS rather than attempting to cross compile in the
development rkt container.

Start by installing the Ocaml and Go compilers as well as the ``libev``
compilation dependency needed to make the ``qemu-tool`` binary. (This is unused
in RktMachine but needed for the compile.)

::

    brew install opam go libev

Next, clean any previous OPAM installation and set up the Ocaml libraries
needed.

.. CAUTION::
   The following instructions are unsuitable if you normally do Ocaml
   development on your macOS. You are unlikely to appreciate your
   ``~/.opam`` directory being cleared.

::

    rm -fr ~/.opam
    opam init --yes
    opam install --yes uri qcow-format ocamlfind conf-libev
    eval `opam config env`

Do the same for Go.

.. CAUTION::
   The following instructions are unsuitable if you normally do Go
   development on your macOS. You are unlikely to appreciate your
   ``~/go`` directory being cleared.

::

    export GOPATH=~/go
    rm -fr $GOPATH

Then add the Corectl repository to your Go tree.

::

    mkdir -p $GOPATH/src/github.com/TheNewNormal
    cd $GOPATH/src/github.com/TheNewNormal
    git clone https://github.com/TheNewNormal/corectl
    cd corectl

Finally, select the release to build and perform the build.

::

    git checkout v0.7.18

    make clean
    make tarball

The output binaries are placed in
``~/go/src/github.com/TheNewNormal/corectl/bin``. It is only necessary to
copy ``corectl``, ``corectld``, and ``corectld.runner`` to the RktMachine
repository since the QEMU tool is unused. The binaries should be placed under
``src/bin`` in the RktMachine repository.
