.. _workingwithrkt:

Working With rkt
----------------
The `rkt <https://github.com/rkt/rkt>`_ tool is a command line interface for
running application containers.

There is an introduction to using rkt in the :ref:`tutorial`. Alternatively,
you can see the `Getting Started with rkt`_ guide in the `rkt documentation`_.
If you are already familiar with Docker, then this Medium post about
`Moving from Docker to rkt`_ may also help you.

.. _Getting Started with rkt: https://coreos.com/rkt/docs/latest/getting-started-guide.html
.. _rkt documentation: https://coreos.com/rkt/docs/latest
.. _Moving from Docker to rkt: https://medium.com/@adriaandejonge/moving-from-docker-to-rkt-310dc9aec938

The rkt command comes with built in help pages:

::

    $ rkt --help
    NAME:
        rkt - rkt, the application container runner

    USAGE:
        rkt [command]

    VERSION:
        1.21.0

    COMMANDS:
        api-service         Run API service (experimental)
        cat-manifest        Inspect and print the pod manifest
        config              Print configuration for each stage in JSON format
        enter               Enter the namespaces of an app within a rkt pod
        export              Export an app from an exited pod to an ACI file
        fetch               Fetch image(s) and store them in the local store
        gc                  Garbage collect rkt pods no longer in use
        image cat-manifest  Inspect and print the image manifest
        image export        Export a stored image to an ACI file
        image extract       Extract a stored image to a directory
        image gc            Garbage collect local store
        image list          List images in the local store
        image render        Render a stored image to a directory with all its dependencies
        image rm            Remove one or more images with the given IDs or image names from the local store
        list                List pods
        metadata-service    Run metadata service
        prepare             Prepare to run image(s) in a pod in rkt
        rm                  Remove all files and resources associated with an exited pod
        run                 Run image(s) in a pod in rkt
        run-prepared        Run a prepared application pod in rkt
        status              Check the status of a rkt pod
        stop                Stop a pod
        trust               Trust a key for image verification
        version             Print the version and exit
        help                Help about any command

    DESCRIPTION:
        A CLI for running app containers on Linux.

        To get the help on any specific command, run "rkt help command".

    OPTIONS:
          --debug[=false]                   print out more debug information to stderr
          --dir=/var/lib/rkt                rkt data directory
          --insecure-options=none           comma-separated list of security features to disable.
                                            Allowed values: "none", "image", "tls", "ondisk", "http",
                                            "pubkey", "capabilities", "paths", "seccomp", "all-fetch",
                                            "all-run", "all"
          --local-config=/etc/rkt           local configuration directory
          --system-config=/usr/lib/rkt      system configuration directory
          --trust-keys-from-https[=false]   automatically trust gpg keys fetched from https
          --user-config=                    user configuration directory

If you have followed the :ref:`tutorial` or are already running a rkt container
then the running container can be seen using the rkt list command.\

::

    $ rkt list
    UUID        APP             IMAGE NAME                      STATE   CREATED     STARTED     NETWORKS
    c7d3aaca    dev-rktmachine  woofwoofinc.dog/dev-rktmachine  running 6 days ago  6 days ago  default:ip4=172.16.28.2

Stop a running container using rkt stop.

.. NOTE::
   The rkt stop command is run as the superuser because root privileges are
   required to start/stop containers on a system. However, listing the
   containers as earlier is fine as a regular user since it only needs access
   to rkt management data, not kernel calls.

::

    $ sudo rkt stop c7d3aaca
    "c7d3aaca-8536-43f3-9b83-1ba8887b4fbb"

The container will show as exited in the list now.

::

    $ rkt list
    UUID        APP             IMAGE NAME                      STATE   CREATED     STARTED     NETWORKS
    c7d3aaca    dev-rktmachine  woofwoofinc.dog/dev-rktmachine  exited  6 days ago  6 days ago

Eventually, stopped containers can be removed by running rkt gc. This has a
grace period of 30 minutes where stopped containers are not removed. The
garbage collection can be forced by setting the grace period to zero with
``--grace-period=0s``.


::

    $ sudo rkt gc --grace-period=0s
    Garbage collecting pod "c7d3aaca-8536-43f3-9b83-1ba8887b4fbb"

    $ rkt list
    UUID        APP             IMAGE NAME                      STATE   CREATED     STARTED     NETWORKS


To see which container images are available to run, use rkt image list.

::

    $ rkt image list
    ID                  NAME                                SIZE    IMPORT TIME LAST USED
    sha512-e1e9e1991658 woofwoofinc.dog/dev-rktmachine      1.8GiB  6 days ago  6 days ago
    sha512-fdd18d9c2103 coreos.com/rkt/stage1-coreos:1.21.0 184MiB  6 days ago  6 days ago

It is common to start interactive containers for development workflows and
typically useful to mount directories, e.g. source code, from the host computer
via the NFS mount on the CoreOS VM.

An example is:

::

    $ sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        woofwoofinc.dog/dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine \
        --exec /bin/bash

In this case, the current working directory is mounted onto the container. This
is a handy shortcut when already in an NFS mounted directory on the CoreOS VM.
On the container, this directory is available at ``/rktmachine``.

Use 'exit' to finish the interactive session.

.. NOTE::
   To exit a non-interactive container or a non-responsive interactive
   container, press Ctrl+] three times quickly.

To delete a container image entirely use rkt image rm. This will mean that new
instances of the container cannot be started until the container is
reinstalled.

::

    $ rkt image rm woofwoofinc.dog/dev-rktmachine
    successfully removed aci for image: "sha512-e1e9e1991658e3908f817164f01292ecaf44bed95e25167020c6cbe28d6b863b"
    rm: 1 image(s) successfully removed

The images can be garbage collected similarly to the running containers but
using the rkt image gc command instead.

::

   $ sudo rkt image gc


Building Containers for rkt
~~~~~~~~~~~~~~~~~~~~~~~~~~~
The rkt documentation contains a guide on `Building an App Container image`_
based on using acbuild_.

.. _Building an App Container image: https://coreos.com/rkt/docs/latest/trying-out-rkt.html#building-an-app-container-image
.. _acbuild: https://github.com/containers/build

The `acbuild documentation`_ contains detailed information on using the tool.
In particular, see the `acbuild Getting Started guide`_ and
`acbuild subcommand documentation`_.

.. _acbuild documentation: https://github.com/containers/build/blob/master/README.md
.. _acbuild Getting Started guide: https://github.com/containers/build/blob/master/Documentation/getting-started.md
.. _acbuild subcommand documentation: https://github.com/containers/build/tree/master/Documentation/subcommands

The `rkt-containers repository`_ contains build script examples illustrating
how to use ``acbuild`` to make a variety of containers for development use.

.. _rkt-containers repository: https://github.com/woofwoofinc/rkt-containers

.. CAUTION::
   Most services do not default to listening to all network interfaces. Instead
   they typically just listed on the local ``localhost`` network. This is a
   problem when specifying service to run inside a container because the
   ``localhost`` network on the container will not be available outside of the
   container. This means we cannot access the container service from our host
   computer.

   Most services have command line options to change the network interface on
   which the service listens. Usually, it is sufficient to change this to be
   the ``0.0.0.0`` interface, i.e. listen on all network interfaces on the
   container. This will then include the external network interface which our
   host computer will use to attempt to connect to the container.
