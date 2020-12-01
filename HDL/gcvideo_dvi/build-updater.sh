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
                         build/main-dual-gc/toplevel_dual.tagmain \
                         build/main-dual-wii/toplevel_dual.tagmain \

./scripts/buildupdate.pl $UPDATER_WII binaries/updater-$VERSION-wii.dol \
                         build/main-p2xh-gc/toplevel_p2xh.tagmain \
                         build/main-p2xh-wii/toplevel_p2xh.tagmain \
                         build/main-shuriken-gc/toplevel_shuriken.tagmain \
                         build/main-shuriken-wii/toplevel_shuriken.tagmain \
                         build/main-shuriken-v3-gc/toplevel_shuriken.tagmain \
                         build/main-shuriken-v3-wii/toplevel_shuriken.tagmain \
                         build/main-dual-gc/toplevel_dual.tagmain \
                         build/main-dual-wii/toplevel_dual.tagmain \
