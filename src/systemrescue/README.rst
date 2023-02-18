.. src/systemrescue/README.rst
.. ===========================
..
.. Copying
.. -------
..
.. Copyright (c) 2023 universe/images authors and contributors.
..
.. This file is part of the *universe/images* project.
..
.. *universe/images* is a free software project. You can redistribute it and/or
.. modify it following the terms of the MIT License.
..
.. This software project is distributed *as is*, WITHOUT WARRANTY OF ANY KIND;
.. including but not limited to the WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
.. PARTICULAR PURPOSE and NONINFRINGEMENT.
..
.. You should have received a copy of the MIT License along with
.. *universe/images*. If not, see <http://opensource.org/licenses/MIT>.

SystemRescue
============

`SystemRescue <https://www.system-rescue.org/>`_ is a Linux system rescue
toolkit available as a bootable medium for administrating or repairing your
system and data after a crash.

It aims to provide an easy way to carry out admin tasks on your computer, such
as creating and editing the hard disk partitions.

This image creates a bootable ISO file of SystemRescue.


Build
-----

The image is build using `Packer <https://www.packer.io/>`_.

.. code-block:: command

    $ packer build image.pkr.hcl


Variables
^^^^^^^^^

The following variables are available to customize the images.


``arch`` – **string** (Default: ``amd64``)
    The architecture for which the image is being built.

``authorized_keys`` – **string** (Default: ````)
    Path to a file listing the public SSH keys authorized to log into the
    system. The file must list one key per line matching the format:


    .. code-block::

        <KEY_NAME> <KEY_SPECIFICATION>


    It is important that the key name does not include any spaces.

``recipe_directory`` – **string** (Default: ``recipe``)
    Path to a directory listing the `recipes
    <https://www.system-rescue.org/scripts/sysrescue-customize/#automatic-mode>`_
    to apply changes on the built ISO image.

``version`` – **string** (Default: ``9.06``)
    Version of SystemRescue image being built.


Output
^^^^^^

The build process generates an ISO file and a SHA-256 checksum of the generated
ISO.
