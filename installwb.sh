#!/bin/bash
#
# Helper script to install a list of workbenches

set -ex

ref=../freecad-daily*.deb
if test -f "$ref"; then
    ref="-r $ref"
else
    ref=
fi
img_date=`date $ref +%Y%m%d%H%M`

ver=
if [ "${FMK_REPO_VER:=1}" = 1 ]; then
    ver=$FMK_REPO_HASH
fi

base_path=$FMK_WB_BASE_PATH
if test -z $base_path; then
    check_path=./usr/share/freecad-daily
    if test -d $check_path; then
        base_path=$check_path
    else
        base_path=.
    fi
fi

for wb in $FMK_WB_LIST; do
    url=FMK_WB_URL_$wb
    url=${!url}
    if test -z $url; then
        echo "no url for $wb"
        exit 1
    fi
    branch=FMK_WB_BRANCH_$wb
    branch=${!branch:=master}
    path=FMK_WB_PATH_$wb
    path=$base_path/${!path:=Mod}

    mkdir -p $path
    pushd $path

    rm -rf $wb
    git clone -b $branch --depth 1 --single-branch $url $wb

    cd $wb

    if test $ref; then
        date=`date -d "$(git show -s --format=%aI)" +%Y%m%d%H%M`
        if [ $date -gt $img_date ]; then
            img_date=$date
        fi
    fi

    sub=FMK_WB_SUB_$wb
    sub=${!sub}
    if test "$sub"; then
        git submodule update --depth 1 --init $sub
    fi

    addver=FMK_WB_VER_$wb
    if [ "${!addver:=1}" = 1 ]; then
        test -z $ver || ver=$ver-
        ver=$ver$(git show -s --format=%h)
    fi
    popd

    find $path -name ".git*" -print | xargs rm -rf

    if test "$FMK_WB_SCRIPT"; then
        $FMK_WB_SCRIPT $path
    fi
done

# echo "$FMK_IMG_NAME-${img_date:0:8}-$ver" > ${FMK_REPO_VER_PATH:=../VERSION}
