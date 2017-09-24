.. _dev:

Development Tools Container
===========================
The project source comes with a ``dev`` directory which contains a script for
building a rkt Ubuntu container with useful development tools.

To build this, start the CoreOS VM from RktMachine and SSH to it. Then copy the
``dev/dev-rktmachine.acbuild.sh`` script from your ``/Users`` NFS mount to the
CoreOS VM.

Building
--------
Build the container using the provided build script:

::

    ./dev-rktmachine.acbuild.sh

This will make a ``dev-rktmachine.oci`` in the directory. Convert this to
``dev-rktmachine.aci`` for installation into rkt:

::

    gunzip < dev-rktmachine.oci > dev-rktmachine.oci.tar
    docker2aci dev-rktmachine.oci.tar
    rm dev-rktmachine.oci.tar
    mv dev-rktmachine-latest.aci dev-rktmachine.aci

Install this into rkt:

::

    rkt --insecure-options=image fetch ./dev-rktmachine.aci

This container is intended for interactive use, so to run it with rkt use:

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine

The current working directory is available on the container at
``/rktmachine``.
