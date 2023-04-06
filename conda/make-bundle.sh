#!/bin/bash

set -ex

tag=${1:=tip}
py=${2:=3.10}
appdir=build
out=build/out
mkdir -p $out
conda_cmd=$conda
os=

changelog=`sed -n "/-- $tag --/=" changelog.md`
if test -z $changelog; then
    echo "Warning: no change log"
    echo "Release $tag" > changelog.txt
else
    head -$((changelog - 1)) changelog.md > changelog.txt
    echo "Changelog:"
    cat changelog.txt
fi

pkgs="python=*$py calculix blas=*=openblas git gitpython \
      matplotlib-base numpy sympy pandas gmsh scipy six qtpy \
      pyyaml ifcopenshell libredwg pycollada \
      lxml xlutils olefile requests \
      blinker opencv qt.py nine docutils fmt jupyter notebook"


arch=`uname -m`
case $arch in
aarch64)
    ;;
arm64)
    ;;
64)
    arch=x86_64
    ;;
esac

case `uname` in
Windows*)
    os=Win
    ;;
Linux*)
    os=Linux
    cp -a conda/AppDir $appdir
    appdir=$appdir/AppDir
    pkgs="$pkgs appimage-updater-bridge"
    if [ $arch != aarch64 ]; then
        pkgs="$pkgs fcitx-qt5"
    fi
    ;;
Darwin*)
    os=MacOS
    cp -a MacBundle $appdir
    appdir=$appdir/FreeCAD.app/Contents/Resources
    ;;
esac

release=
branding=
pkgs="$pkgs freecad-rt=*$tag"
case $tag in
*tip)
    img_prefix="FreeCAD-asm3-Tip"
    release=Tip
    branding=branding/asm3-daily
    ;;
*edge)
    img_prefix="FreeCAD-asm3-Edge"
    release=Edge
    branding=branding/asm3-daily
    ;;
*stable)
    img_prefix="FreeCAD-asm3-Stable"
    branding=branding/asm3
    release=latest
    ;;
*)
    echo "Invalid tag"
    exit 1
esac

image_name=$img_prefix-$tag-py$py-$arch

if [ $os = win ]; then
    appdir=$appdir/$image_name
    mkdir -p $appdir
fi

$conda_cmd create -p $appdir $pkgs \
    --copy -c realthunder -c freecad/label/dev -c conda-forge -y

export FMK_WB_BASE_PATH=$appdir
export FMK_WB_LIST="asm3"
export FMK_WB_PATH_asm3=Mod
export FMK_WB_URL_asm3=https://github.com/realthunder/FreeCAD_assembly3
./installwb.sh 

# installing some additional libraries with pip
# conda run -p $appdir pip install https://github.com/looooo/freecad_pipintegration/archive/master.zip

jupyter_dir=$appdir/share/jupyter/kernels
if test -d $jupyter_dir; then
    if ! $conda_cmd run -p $appdir pip install git+https://github.com/realthunder/freecad_jupyter; then
        echo Failed to install jupyter
    else
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
fi

# conda run -p $appdir python -m compileall $appdir/usr/lib/python$py_ver $appdir/usr/Mod

# uninstall some packages not needed
$conda_cmd uninstall -p $appdir libclang --force -y || true

$conda_cmd list -e -p $appdir > $appdir/packages.txt

if test $win; then
    cd $appdir
    # Why do we get permission denied error if move mingw64?
    # mv Library/mingw64 .
    cp -a Library/mingw64 .
    mv Library/plugins .
    mkdir -p bin
    mv share Scripts Lib DLLs bin/
    mv packages.txt python* msvc* ucrt* bin/
    rm -f Library/bin/api*.dll
    mv Library/bin/*.dll bin/
    mv Library/bin/FreeCAD* bin/
    for dir in Mod Ext data lib resources translations; do
        mv Library/$dir .
    done
    for file in QtWebEngineProcess assistant ccx gmsh; do
        mv Library/bin/$file.exe bin/
    done
    # cp ../ssl-patch.py bin/Lib/ssl.py
    rm -rf tmp Tools Menu Library conda-meta etc include fonts libs sip
    find . -maxdepth 1 -type f -delete
    find . -type f \( -name "*.pdb" -o -name "*.lib" -o -name __pycache__ \) -delete
    cat > bin/qt.conf << EOS
[Paths]
Prefix = ./../
EOS

    $branding/install.sh $branding $appdir

    cat << EOS > $appdir/RunFreeCAD.bat 
cd %~dp0/bin
set PATH=%~dp0\mingw64\bin;%PATH%
set SSL_CERT_FILE=%~dp0\bin\Lib\site-packages\certifi\cacert.pem
FreeCADLink.exe
EOS
    cat << EOS > $appdir/RunJupyter.bat 
set QT_AUTO_SCREEN_SCALE_FACTOR=1
cd %~dp0/bin
set PATH=%~dp0\mingw64\bin;%PATH%
set SSL_CERT_FILE=%~dp0\bin\Lib\site-packages\certifi\cacert.pem
python.exe -m jupyter notebook
EOS

    7z a $out/$image_name.7z $appdir

    exit
fi

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

$branding/install.sh $branding $appdir

if [ $os = osx ]; then
    hdiutil create -fs HFS+ -srcfolder $appdir $out/$image_name.dmg
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
    curl -OL https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$arch.AppImage
    chmod +x appimagetool-$arch.AppImage
    ./appimagetool-$arch.AppImage --appimage-extract
    mv squashfs-root $apptool
fi

if [[ $appdir == */usr ]]; then
    appdir="$appdir/../"
fi

zsync='-u gh-releases-zsync|realthunder|FreeCAD|$release|'"$img_prefix"'-*-'"$arch.AppImage.zsync"

export VERSION="$tag-$py"
ARCH=x86_64 $apptool/AppRun $appdir $zsync ${image_name}.AppImage

