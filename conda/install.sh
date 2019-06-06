#!/bin/bash

set -e

dir="$(dirname "$(readlink -f $0)")"

APPDIR=$1
if test -z $APPDIR; then
    APPDIR=AppDir_asm3
fi

mkdir -p $APPDIR/usr
cp $dir/AppDir/* $APPDIR/

conda create \
    -p $APPDIR/usr \
    calculix blas=*=openblas gitpython \
    numpy matplotlib scipy sympy pandas six pyyaml \
    qt=5.6.3 \
    --copy \
    --no-default-packages \
    -c freecad \
    -c conda-forge \
    -y

conda install -p $APPDIR/usr --use-local freecad-asm3 -y

# install asm3 workbench
pushd $APPDIR/usr/Ext/freecad
rm -rf asm3
git clone https://github.com/realthunder/FreeCAD_assembly3.git asm3
popd

# installing some additional libraries with pip
conda run -p $APPDIR/usr pip install https://github.com/looooo/freecad_pipintegration/archive/master.zip

# remove bloat
pushd "$APPDIR"/usr
rm -rf pkgs
find -type d -iname '__pycache__' -print0 | xargs -0 rm -r
find -type f -iname '*.so*' -print -exec strip '{}' \;
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

version_name=FreeCAD-asm3-Conda_Py3Qt5_glibc2.12-x86_64

APPTOOL=appimagetool
if ! test -e $APPTOOL/AppRun; then
    if test -d $APPTOOL; then
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
    mv squashfs-root $APPTOOL
fi

ARCH=x86_64 $APPTOOL/AppRun $APPDIR ${version_name}.AppImage

