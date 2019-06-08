#!/bin/bash

set -e

dir="$(dirname "$(readlink -f $0)")"

image_name=${FMK_CONDA_IMG_NAME:="FreeCAD-asm3-Conda_Py3Qt5_glibc2.12-x86_64"}
appdir=${FMK_CONDA_APPDIR:="AppDir_asm3"}

rm -rf $appdir/*
mkdir -p $appdir/usr
cp $dir/AppDir/* $appdir/

conda create \
    -p $appdir/usr \
    calculix blas=*=openblas git gitpython \
    numpy matplotlib scipy sympy pandas six pyyaml \
    qt=5.6.3 \
    occt \
    --copy \
    --no-default-packages \
    -c freecad \
    -c conda-forge \
    -y

conda install -p $appdir/usr --use-local freecad-asm3 -y

if test "$FMK_CONDA_FC_EXTRA"; then
    cp -a "$FMK_CONDA_FC_EXTRA"/* $appdir/usr/
fi

# installing some additional libraries with pip
conda run -p $appdir/usr pip install https://github.com/looooo/freecad_pipintegration/archive/master.zip

# remove bloat
pushd "$appdir"/usr
rm -rf pkgs
find -type d -iname '__pycache__' -print0 | xargs -0 rm -r
# find -type f -iname '*.so*' -print -exec strip '{}' \;
find -type f -iname '*.a' -print -delete
rm -rf lib/cmake/
rm -rf include/
rm -rf share/{gtk-,}doc
rm -rf share/man
#rm -rf lib/python?.?/site-packages/{setuptools,pip}
#rm -rf lib/python?.?/distutils

mv bin bin_tmp
mkdir bin
cp bin_tmp/FreeCAD bin/
cp bin_tmp/FreeCADCmd bin/
cp bin_tmp/ccx bin/
cp bin_tmp/python bin/
cp bin_tmp/pip bin/
cp bin_tmp/pyside2-rcc bin/
cp bin_tmp/assistant bin/
sed -i '1s|.*|#!/usr/bin/env python|' bin/pip
rm -rf bin_tmp

popd

apptool=appimagetool
if ! test -e $apptool/AppRun; then
    if test -d $apptool; then
        echo "Invalid appimagetool directory"
        exit 1
    fi
    if test -d squashfs-root; then
        echo "There is an existing AppImage extracted directory 'squashfs-root'"
        exit 1
    fi
    curl -OL https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
    ./appimagetool-x86_64.AppImage --appimage-extract
    mv squashfs-root $apptool
fi

ARCH=x86_64 $apptool/AppRun $appdir ${image_name}.AppImage

