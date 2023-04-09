#!/bin/bash

set -e
src=$1
dst=$2

if test -f $dst/../MacOS/FreeCAD; then
    cp -a $src/MacBundle/* $dst/../
    sed -i '' "s@_FC_BUNDLE_VERSION_@${FMK_BUILD_DATE}@g" $dst/../Info.plist
    mv $dst/../MacOS/FreeCAD $dst/../MacOS/FreeCADLink
elif test -f $dst/MacOS/FreeCAD; then
    cp -a $src/MacBundle/* $dst/
    sed -i '' "s@_FC_BUNDLE_VERSION_@${FMK_BUILD_DATE}@g" $dst/Info.plist
    mv $dst/MacOS/FreeCAD $dst/MacOS/FreeCADLink
elif test -f $dst/bin/FreeCAD; then
    find $dst/share/ -type f -name org.freecadweb.FreeCAD* -exec \
        bash -c "sed -i 's|org.freecadweb.FreeCAD|$id|' "'$1 && mv $1 ${1%org.freecadweb.FreeCAD*}'$id'${1#*org.freecadweb.FreeCAD}' bash {} \;
    rm -f $dst/../*.desktop $dst/../*.png
    id=org.freecadweb.FreeCAD.Link
    cp $src/AppDir/$id.desktop $src/AppDir/$id.png $dst/../
    cp -a $src/icons $dst/share/
    mv $dst/bin/FreeCAD $dst/bin/FreeCADLink
elif test -f  $dst/bin/FreeCAD.exe; then
    mv $dst/bin/FreeCAD.exe $dst/bin/FreeCADLink.exe
else
    echo failed to find bin directory
    exit 1
fi

if test -d $src/Mod; then
    cp -a $src/Mod/* $dst/Mod/
fi

mkdir -p $dst/bin
cp $src/branding/* $dst
mv $dst/branding.xml $dst/bin
if test $FMK_BUILD_DATE; then
    sed -i -e "s@_FC_VERSION_MAJOR_@${FMK_BUILD_DATE:0:4}@g" $dst/bin/branding.xml
    month=${FMK_BUILD_DATE:4:2}
    sed -i -e "s@_FC_VERSION_MINOR_@${month#0}${FMK_BUILD_DATE:6}@g" $dst/bin/branding.xml
    sed -i -e "s@_FC_VERSION_MINOR2_@${FMK_BUILD_DATE:4:2}.${FMK_BUILD_DATE:6}@g" $dst/bin/branding.xml
    sed -i -e "s@_FC_BUILD_DATE_@$FMK_BUILD_DATE@g" $dst/bin/branding.xml
    rm -f "$dst/bin/branding.xml-e"
fi

