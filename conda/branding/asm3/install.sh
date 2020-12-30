#!/bin/bash

set -e
src=$1
dst=$2

cp $src/branding/branding.xml $dst/bin/
if test $FMK_BUILD_DATE; then
    sed -i -e "s@_FC_VERSION_MAJOR_@${FMK_BUILD_DATE:0:4}@g" $dst/bin/branding.xml
    sed -i -e "s@_FC_VERSION_MINOR_@${FMK_BUILD_DATE:4:2}${FMK_BUILD_DATE:6}@g" $dst/bin/branding.xml
    sed -i -e "s@_FC_BUILD_DATE_@$FMK_BUILD_DATE@g" $dst/bin/branding.xml
fi
cp $src/branding/* $dst/
cp $src/AppDir/* $dst/

if test -d $dst/share; then
    cp -a $src/icons $dst/share/
    mv $dst/bin/FreeCAD $dst/bin/FreeCADLink
elif test -f $dst/bin/FreeCAD.exe; then
    mv $dst/bin/FreeCAD.exe $dst/bin/FreeCADLink.exe
fi


