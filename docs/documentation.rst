.. _documentation:

Documentation
=============
The project documentation under ``docs`` can be compiled using Sphinx_. Output
is placed in ``docs/_build/html``.

.. _Sphinx: http://www.sphinx-doc.org

::

    cd docs
    make clean html

The development container provides an installation of Python and Sphinx which
can be used to build this documentation also.

Build the container as described in :ref:`dev`. Then change to the ``docs``
directory that you want to compile and start the container with this directory
mounted at ``/rktmachine``.

::

    sudo rkt run \
        --interactive \
        --volume rktmachine,kind=host,source=$(pwd) \
        dev-rktmachine \
        --mount volume=rktmachine,target=/rktmachine

Inside the container, change directory to ``/rktmachine`` and run the build
command.

::

    cd /rktmachine
    make clean html

The compiled document is written to the shared location and is available on the
host machine under ``docs/_build/html``.
