#!/bin/bash

set -e

./build-all.sh

VERSION=`make printversion`
UPDATER_GC=../../Updater/obj-gc/gcvupdater.dol
UPDATER_WII=../../Updater/obj-wii/gcvupdater.dol

if [ ! -e $UPDATER_GC ] || [ ! -e $UPDATER_WII ]; then
    pushd ../../Updater
    make TARGET=gc
    make TARGET=wii
    popd
fi

./scripts/buildupdate.pl $UPDATER_GC binaries/updater-$VERSION-gc.dol \
                         build/main-p2xh-gc/toplevel_p2xh.tagmain \
                         build/main-p2xh-wii/toplevel_p2xh.tagmain \
                         build/main-shuriken-gc/toplevel_shuriken.tagmain \
                         build/main-shuriken-wii/toplevel_shuriken.tagmain \
                         build/main-shuriken-v3-gc/toplevel_shuriken.tagmain \
                         build/main-shuriken-v3-wii/toplevel_shuriken.tagmain \
                         build/main-dual-gc/toplevel_gcdual.tagmain \
                         build/main-dual-wii/toplevel_wiidual.tagmain \
                         build/main-gcplug/toplevel_shuriken.tagmain

HBCDIR=build/GCVideo-Updater-$VERSION
mkdir $HBCDIR

./scripts/buildupdate.pl $UPDATER_WII $HBCDIR/boot.dol \
                         build/main-p2xh-wii/toplevel_p2xh.tagmain \
                         build/main-shuriken-wii/toplevel_shuriken.tagmain \
                         build/main-shuriken-v3-wii/toplevel_shuriken.tagmain \
                         build/main-dual-wii/toplevel_wiidual.tagmain

./scripts/xmlgen.pl $VERSION $HBCDIR/meta.xml
cd build
zip -9Xr ../binaries/updater-$VERSION-wii.zip GCVideo-Updater-$VERSION
