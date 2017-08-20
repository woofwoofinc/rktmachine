Releasing
---------

Release Checklist
~~~~~~~~~~~~~~~~~
1. Check version number is correct in ``Info.plist`` and ``docs/conf.py``.
2. Build release DMG and upload to GitHub releases.
3. Build documentation and upload to GitHub pages.
4. Update version numbers for next development cycle.


Building a Release DMG
~~~~~~~~~~~~~~~~~~~~~~
Prepare a release by building the distributable DMG disk image archive file to
contain the RktMachine binary.

First build an archive in Xcode by selecting ``Product -> Archive``. On success
this opens a listing of the previously built archives. Select the latest, i.e.
the one just created, and use the export options from the panel on the right
hand side to export the archive as a macOS app.

This prompts for a location to write the exported macOS app. Change to this
directory in the terminal once it is complete. There will be a
``RktMachine.app`` file present in the directory.

Then follow this `StackOverflow answer on creating DMG packages`_.

.. _StackOverflow answer on creating DMG packages: http://stackoverflow.com/a/1513578

Create an empty ``pack.temp.dmg`` to build the RktMachine distribution. Attach
the DMG file to ``/Volumes`` and take the device identifier from the output
information so we can reference it later.

::

    hdiutil create \
        -srcfolder . \
        -volname "RktMachine" \
        -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -megabytes 128 \
        pack.temp.dmg

    device=$(
        hdiutil attach -readwrite -noverify -noautoopen "pack.temp.dmg" | \
            egrep '^/dev/' | \
            sed 1q | \
            awk '{ print $1 }'
    )

Execute some AppleScript to layout the DMG appearance, let icon sizes, and
turn off toolbars, etc.

::

    echo '
      tell application "Finder"
        tell disk "RktMachine"
          open
          set current view of container window to icon view
          set toolbar visible of container window to false
          set statusbar visible of container window to false
          set the bounds of container window to {400, 100, 750, 350}
          set theViewOptions to the icon view options of container window
          set arrangement of theViewOptions to not arranged
          set icon size of theViewOptions to 72
          make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
          set position of item "'RktMachine.app'" of container window to {100, 100}
          set position of item "Applications" of container window to {250, 100}
          close
          open
          update without registering applications
          delay 5
          close
        end tell
      end tell
    ' | osascript

Remove write permissions from the files on the disk image and eject it.

::

    chmod -Rf go-w /Volumes/RktMachine
    sync
    sync
    hdiutil detach ${device}

Finally, convert the temporary DMG file to the final compressed format and clean
up.

::

    hdiutil convert \
        pack.temp.dmg \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o RktMachine.dmg

    rm -f pack.temp.dmg

The final DMG image is output as ``RktMachine.dmg``.


Preparing the GitHub Release
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Take the SHA256 of the ``RktMachine.dmg`` binary:

::

    shasum -a 256 RktMachine.dmg

Then create a new RktMachine release on the `GitHub Releases`_ page. The
release should be named the same as the version number in ``Info.plist``
and also be tagged with this value.

.. _GitHub Releases: https://github.com/woofwoofinc/rktmachine/releases

The release text should include the SHA256 value generated earlier. The
following is a template for the release text.

::

    Release <version> of RktMachine for macOS.

    sha256: cce3abfaf7b4aa4652ccdb58a607b84a346a906685afe159ca89bac08a9b355e


Publishing the Documentation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RktMachine documentation is published to `woofwoofinc.github.io/rktmachine`_
using `GitHub Pages`_.

.. _woofwoofinc.github.io/rktmachine: https://woofwoofinc.github.io/rktmachine
.. _GitHub Pages: https://pages.github.com

First build the documentation as described in :ref:`documentation`.

The GitHub configuration for RktMachine is to serve documentation from the
``gh-pages`` branch. Rather than attempt to build a new ``gh-pages`` in the
current repository, it is simpler to copy the repository, change to
``gh-pages`` in the repository copy, and clean everything from there. This has
the advantage of not operating in the current repository too so it is
non-destructive.

Create a copy of the RktMachine repository.

::

    cp -r rktmachine rktmachine-gh-pages

Then change into the new repository and swap to the ``gh-pages`` branch.

::

    pushd rktmachine-gh-pages > /dev/null
    git checkout -b gh-pages

Clear out everything in the branch. This uses dot globing and extended glob
options to arrange deletion of everything except the .git directory.

::

    shopt -s dotglob
    shopt -s extglob
    rm -fr !(.git)

    shopt -u extglob
    shopt -u dotglob

Next, copy in the contents of ``docs/_build/html`` from the main RktMachine
repository. This is the latest build of the documentation. Dot globing is
used again since the dot files in the ``docs/_build/html`` directory are also
needed.

::

    shopt -s dotglob
    cp -r ../rktmachine/docs/_build/html/* .

    shopt -u dotglob

Commit the documentation and push the ``gh-pages`` branch to GitHub.

::

    git add -A
    git commit -m "Add latest documentation."
    git push origin gh-pages

Then clean up the temporary repository.

::

    popd > /dev/null
    rm -fr rktmachine-gh-pages
