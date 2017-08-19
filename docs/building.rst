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
    rkt --insecure-options=image fetch ./dev-rktmachine.aci

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

- ``acbuild`` binaries for building new container images on the CoreOS VM.
- ``skopeo`` for working with and converting container images on the CoreOS VM.
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

Alternatively to build the latest ``acbuild`` from master instead, start the
container as before.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

Change to the ``/rktmachine`` directory and get the latest version of the
``acbuild`` source code:

::

    cd /rktmachine
    git clone https://github.com/containers/build acbuild
    cd acbuild

Run the build script:

::

    ./build

Then exit the container and copy the binaries to the ``tools`` directory. Add
the setuid on the ``acbuild`` binary as before.

::

    sudo cp acbuild/bin/* tools
    sudo chmod u+s tools/acbuild

Adding skopeo_ is more involved since it is not provided as a statically linked
binary. It is relatively easy to build as a static binary though.

We need to build statically linked binaries because the bare CoreOS VM that we
aim to run it on does not have all the necessary dynamic libraries available.

Since CoreOS does not have a build chain, we need to reenter the container and
build ``skopeo`` there.

.. _skopeo: https://github.com/projectatomic/skopeo

Reenter the container.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

Then get the ``skopeo`` sources and create a source tree for Go building.

::

    export GOPATH=~/go

    git clone https://github.com/projectatomic/skopeo $GOPATH/src/github.com/projectatomic/skopeo
    cd $GOPATH/src/github.com/projectatomic/skopeo

The ``skopeo`` build provides a target for performing a statically linked
build. We use that together with build tags to exclude shared libraries
unavailable on CoreOS as well as to build usign a pure Go network library to
avoid other unavailable shared library issues on the CoreOS VM.

::

    make binary-local-static BUILDTAGS="containers_image_ostree_stub exclude_graphdriver_devicemapper netgo"

The resulting binary is placed at ``./skopea``. Copy this to the
``tools`` directory. In this case, setuid is not needed.

::

    cp skopeo /rktmachine/tools

Adding Avahi_ is a more difficult process since it is not provided as a
statically linked binary. The libdaemon0_ dependency also needs to be compiled
with ``-fPIC``.

.. _Avahi: http://www.avahi.org
.. _libdaemon0: http://0pointer.de/lennart/projects/libdaemon

Still in the container, change to the ``/rktmachine`` directory.

::

    cd /rktmachine

First download and extract the ``libdaemon0`` sources.

::

    wget http://0pointer.de/lennart/projects/libdaemon/libdaemon-0.14.tar.gz
    tar xzvf libdaemon-0.14.tar.gz
    cd libdaemon-0.14

Configure to build with ``-fPIC`` and without shared libraries. The ``avahi``
build prefers the shared libraries so by not building them we force the compile
to use the static library instead.

::

    ./configure --prefix=/usr --with-pic --disable-shared
    make clean install

Next download the Avahi source.

::

    cd /rktmachine

    wget https://github.com/lathiat/avahi/archive/v0.7.tar.gz
    tar xzvf v0.7.tar.gz
    cd avahi-0.7

Use Autoconf/Automake to create a ``./configure`` file. There are a number of
warnings and cautions in the following but the produced binary appears to work.

::

    ./autogen.sh
    autoreconf -i
    automake --add-missing

Build ``avahi`` with a set of options that turns nearly everything off.

::

    CONFIGURE_OPT="
      --prefix=/rktmachine/install
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

    cd /rktmachine
    cp install/sbin/avahi-daemon /rktmachine/tools

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

Exit the container and copy the ``tools.qcow2`` image to where it is needed,
typically to the RktMachine repository under ``src/vm/tools.qcow2``. As before,
the easiest way to copy the image file to the host machine is to copy it to
the NFS mounted user directory on the CoreOS VM.

Cleanup the build files on the CoreOS VM.

::

    sudo rm -fr acbuild avahi-0.7 v0.7.tar.gz install libdaemon-0.14  \
      libdaemon-0.14.tar.gz tools tools.raw


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

    git clone https://github.com/TheNewNormal/corectl $GOPATH/src/github.com/TheNewNormal/corectl
    cd $GOPATH/src/github.com/TheNewNormal/corectl

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
