#!/bin/bash

set -e

function build () {
    local TARGET="$1"

    rm -rf build
    make TARGET=$TARGET

    zip -9jX binaries/gcvideo-$VERSION-$TARGET.zip \
        build/gcvideo-dvi-$TARGET-$VERSION-M25P40.xsvf \
        build/gcvideo-dvi-$TARGET-$VERSION-spirom.cfi \
        build/gcvideo-dvi-$TARGET-$VERSION-spirom.mcs \
        build/gcvideo-dvi-$TARGET-$VERSION.bit
}

if [ ! -d codegens ]; then
    echo "You seem to be running this from the wrong directory."
    exit 1
fi

VERSION=`make printversion`

mkdir -p binaries

build p2xh-gc
build p2xh-wii
build shuriken-gc
build shuriken-wii
build shuriken-v3-gc
build shuriken-v3-wii
build dual-gc
build dual-wii

rm -rf build
