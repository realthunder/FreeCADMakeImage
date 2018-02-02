#!/bin/bash
#
# Helper script to install a list of workbenches

set -ex

img_date=`date -r ../freecad-daily*.deb +%Y%m%d%H%M`

ver=
if [ "${REPO_VER:=1}" = 1 ]; then
    ver=$REPO_HASH
fi

base_path=${WB_BASE_PATH:=./usr/lib/freecad-daily}

for wb in $WB_LIST; do
    url=WB_URL_$wb
    url=${!url}
    if test -z $url; then
        echo "no url for $wb"
        exit 1
    fi
    branch=WB_BRANCH_$wb
    branch=${!branch:=master}
    path=WB_PATH_$wb
    path=$base_path/${!path:=Mod}

    pushd $path
    git clone -b $branch --depth 1 --single-branch $url $wb

    cd $wb
    date=`date -d "$(git show -s --format=%aI)" +%Y%m%d%H%M`
    if [ $date -gt $img_date ]; then
        img_date=$date
    fi

    sub=WB_SUB_$wb
    sub=${!sub}
    if test "$sub"; then
        git submodule update --depth 1 --init $sub
    fi

    addver=WB_VER_$wb
    if [ "${!addver:=1}" = 1 ]; then
        test -z $ver || ver=$ver-
        ver=$ver$(git show -s --format=%h)
    fi
    popd
done

echo "$IMG_NAME-${img_date:0:8}-$ver" > ${REPO_VER_PATH:=../VERSION}
