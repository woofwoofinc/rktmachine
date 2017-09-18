Frequently Asked Questions
==========================

Why CoreOS?
-----------
CoreOS is a minimal Linux distribution solely designed to support containers on
top of hardware. It is not particularly convenient for development or
administration uses. i.e. there is no compiler, ``/usr`` is read-only, common
dynamic libraries are not installed.

Using a user-focused distribution like Ubuntu for the VM would be more flexible
in many ways. For instance, avahi mDNS could be installed using the apt package
manager instead of by static compilation on a container.

On the other hand, CoreOS does have advantages as the VM installation. It is
designed exclusively to serve almost exactly the role of light intermediate
that is also desireable in our VM requirements. CoreOS default setup supports
the kind of inbetween bridge that the VM is intended to be and allows the rkt
containers to be the primary element of RktMachine instead of the VM.
