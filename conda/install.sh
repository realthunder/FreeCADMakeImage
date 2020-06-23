#!/bin/bash

set -e

appdir=$1
appimage=$2
image_name=${FMK_CONDA_IMG_NAME:="FreeCAD-asm3-Conda_Py3Qt5_glibc2.12-x86_64"}
py_ver=3.7

conda create \
    -p $appdir \
    python=$py_ver \
    calculix blas=*=openblas git gitpython \
    opencamlib matplotlib numpy scipy sympy pandas \
    smesh=8.3.0.3=py37*_10 netgen=6.2.1808=py37* \
    --copy \
    --no-default-packages \
    -c freecad \
    -c conda-forge \
    -y

conda install -p $appdir --use-local coin3d freecad-asm3 solvespace -y

if test "$FMK_CONDA_FC_EXTRA"; then
    cp -a "$FMK_CONDA_FC_EXTRA"/* $appdir
fi

# installing some additional libraries with pip
conda run -p $appdir pip install https://github.com/looooo/freecad_pipintegration/archive/master.zip
# conda run -p $appdir python -m compileall $appdir/usr/lib/python$py_ver $appdir/usr/Mod

pushd "$appdir"

# remove bloat
rm -rf pkgs
find . -type d -iname '__pycache__' -print0 | xargs -0 rm -r
# find -type f -iname '*.so*' -print -exec strip '{}' \;
find . -type f -iname '*.a' -print -delete
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
# cp bin_tmp/assistant bin/
sed -i.bak -e '1s|.*|#!/usr/bin/env python|' bin/pip && rm bin/pip.bak
rm -rf bin_tmp

# we use qt.conf for qt binary relocation. The one inside `bin` is for FreeCAD,
# and another one in `libexec` for QWebEngineProcess, which runs as a separate
# process.
cat > bin/qt.conf << EOS
[Paths]
Prefix = ./../
EOS
cp bin/qt.conf libexec/

if ! test $appimage; then
    exit
fi

replace_path_gen() {
    local path="$1"
    local postfix="$2"
    local plen=${#postfix}
    local len=${#path}
    if [ $len -lt $plen ];then
        exit 1
    fi
    len=$((len-plen))
    local res=$(printf '%*s' "$((len/2))")
    res=${res// /./}
    if [ $((len%2)) -ne 0 ];then
        res+='/'
    fi
    echo "$res$postfix"
}

# Conda installation puts lots of hard coded aboslute path of the installed
# location. The following code is used to replace it with a relative path
# calculated from `bin`. We also make sure to cd to `bin` before starting
# FreeCAD, which is done in AppRun script. 
#
# This solution is probably not as elegant as using qt.conf above for
# relocation, however, changing the path here also solves the
# XmbTextListToTextProperty error message.
#

app_path="$PWD/"
app_path_rpl=$(replace_path_gen "$app_path" ../)
find . -type f -exec sed -i -e "s@$app_path@$app_path_rpl@g" {} \;

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

if [[ $appdir == */usr ]]; then
    appdir="$appdir/../"
fi
ARCH=x86_64 $apptool/AppRun $appdir -u \
    "gh-releases-zsync|realthunder|FreeCAD_Assembly3|latest|FreeCAD-asm3-Conda-Py3-Qt5-*-glibc2.12-x86_64.AppImage" \
    ${image_name}.AppImage

