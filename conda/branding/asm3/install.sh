#!/bin/bash

set -e
src=$1
dst=$2

if test -f $dst/../MacOS/FreeCAD; then
    cp -a $src/MacBundle/* $dst/../
    sed -i '' "s@_FC_BUNDLE_VERSION_@${FMK_BUILD_DATE:0:4}@g" $dst/../Info.plist
    mv $dst/../MacOS/FreeCAD $dst/../MacOS/FreeCADLink
elif test -f $dst/MacOS/FreeCAD; then
    cp -a $src/MacBundle/* $dst/
    sed -i '' "s@_FC_BUNDLE_VERSION_@${FMK_BUILD_DATE:0:4}@g" $dst/Info.plist
    mv $dst/MacOS/FreeCAD $dst/MacOS/FreeCADLink
elif test -f $dst/bin/FreeCAD; then
    rm -f $dst/../freecad_conda.desktop $dst/../freecad_conda.png
    cp $src/AppDir/freecad_link.desktop $src/AppDir/freecad_link.png $dst/../
    cp -a $src/icons $dst/share/
    mv $dst/bin/FreeCAD $dst/bin/FreeCADLink
elif test -f  $dst/bin/FreeCADCmd.exe; then
    mv $dst/bin/FreeCAD.exe $dst/bin/FreeCADLink.exe
else
    echo failed to find bin directory
    exit 1
fi

mkdir -p $dst/bin
cp $src/branding/* $dst
mv $dst/branding.xml $dst/bin
if test $FMK_BUILD_DATE; then
    sed -i -e "s@_FC_VERSION_MAJOR_@${FMK_BUILD_DATE:0:4}@g" $dst/bin/branding.xml
    # trim leading zero
    month=`printf %d ${FMK_BUILD_DATE:4:2}`
    sed -i -e "s@_FC_VERSION_MINOR_@$month${FMK_BUILD_DATE:6}@g" $dst/bin/branding.xml
    sed -i -e "s@_FC_VERSION_MINOR2_@${FMK_BUILD_DATE:4:2}.${FMK_BUILD_DATE:6}@g" $dst/bin/branding.xml
    sed -i -e "s@_FC_BUILD_DATE_@$FMK_BUILD_DATE@g" $dst/bin/branding.xml
    rm -f "$dst/bin/branding.xml-e"
fi

