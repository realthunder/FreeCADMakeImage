#!/bin/bash

set -ex

appdir=$1
appimage=$2
image_name=${FMK_CONDA_IMG_NAME:="FreeCAD-asm3-Conda_Py3Qt5_glibc2.12-x86_64"}

if test "$FMK_CONDA_REQUIRMENTS" && test -f "$FMK_CONDA_REQUIRMENTS"; then
    conda create \
        -p $appdir \
        --file $FMK_CONDA_REQUIRMENTS \
        --no-default-packages \
        -c freecad \
        -c conda-forge \
        -y
else
    appimage_updater=
    if test $appimage; then
        appimage_updater=appimage-updater-bridge
    fi
    conda create \
        -p "$appdir" \
        python=3.9 calculix blas=*=openblas git gitpython \
        opencamlib matplotlib-base numpy sympy pandas $appimage_updater \
        gmsh netgen scipy pythonocc-core six \
        pyyaml ifcopenshell boost-cpp libredwg pycollada \
        lxml xlutils olefile requests openglider \
        blinker opencv qt.py nine docutils jupyter notebook solvespace \
        --copy \
        --no-default-packages \
        -c freecad/label/dev \
        -c freecad \
        -c conda-forge \
        -y
fi

local_pkgs="coin3d $FMK_FREECAD_PKGNAME"
if test $appimage; then
    local_pkgs="$local_pkgs fcitx-qt5"
fi
conda install -p $appdir --use-local $local_pkgs -y

if test "$FMK_CONDA_FC_EXTRA"; then
    cp -a "$FMK_CONDA_FC_EXTRA"/* $appdir
fi

# installing some additional libraries with pip
conda run -p $appdir pip install https://github.com/looooo/freecad_pipintegration/archive/master.zip

jupyter_dir=$appdir/share/jupyter/kernels
if test -d $jupyter_dir; then
    conda run -p $appdir pip install git+https://github.com/realthunder/freecad_jupyter
    rm -rf $jupyter_dir/*
    mkdir -p $jupyter_dir/freecad
    cat > $jupyter_dir/freecad/kernel.json <<EOS
{
    "argv": [
    "python",
    "-m",
    "freecad_jupyter",
    "-f",
    "{connection_file}"
    ],
    "display_name": "FreeCAD",
    "language": "python"
}
EOS
    py3kernel=$jupyter_dir/python3/kernel.json
    if test -f $py3kernel; then
        sed -i -e '1s|././././././././././././/../bin/python|python|' $py3kernel
    fi
fi

# conda run -p $appdir python -m compileall $appdir/usr/lib/python$py_ver $appdir/usr/Mod

# uninstall some packages not needed
conda uninstall -p $appdir gtk2 gdk-pixbuf llvm-tools \
                           llvmdev clangdev clang clang-tools \
                           clangxx libclang libllvm10 --force -y

conda list -e -p $appdir > $appdir/packages.txt

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
cp bin_tmp/gmsh bin/
sed -i.bak -e '1s|.*|#!/usr/bin/env python|' bin/pip && rm bin/pip.bak
if test -f bin_tmp/jupyter; then
    cp bin_tmp/jupyter* bin/
    sed -i -e '1s|.*|#!/usr/bin/env python|' bin/jupyter*
fi
# cp bin_tmp/assistant bin/
rm -rf bin_tmp

# we use qt.conf for qt binary relocation. The one inside `bin` is for FreeCAD,
# and another one in `libexec` for QWebEngineProcess, which runs as a separate
# process.
cat > bin/qt.conf << EOS
[Paths]
Prefix = ./../
EOS
cp bin/qt.conf libexec/

mpmath=lib/python3.8/site-packages/mpmath/ctx_mp_python.py
if test -f $mpmath; then
    sed -i -e "s@other is 0@other == 0@g" $mpmath
fi

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

if test $FMK_BRANDING; then
    recipes/branding/$FMK_BRANDING/install.sh recipes/branding/$FMK_BRANDING $appdir
fi

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
    curl -OL https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
    ./appimagetool-x86_64.AppImage --appimage-extract
    mv squashfs-root $apptool
fi

if [[ $appdir == */usr ]]; then
    appdir="$appdir/../"
fi

zsync='-u gh-releases-zsync|realthunder|FreeCAD_assembly3|latest'
case $image_name in
FreeCAD-asm3-Stable-Conda-Py3-Qt5-*-x86_64)
    zsync="$zsync|FreeCAD-asm3-Stable-Conda-Py3-Qt5-*-x86_64.AppImage.zsync"
    ;;
FreeCAD-asm3-Daily-Conda-Py3-Qt5-*-x86_64)
    zsync="$zsync|FreeCAD-asm3-Daily-Conda-Py3-Qt5-*-x86_64.AppImage.zsync"
    ;;
*)
    zsync=
    ;;
esac

ARCH=x86_64 $apptool/AppRun $appdir $zsync ${image_name}.AppImage

