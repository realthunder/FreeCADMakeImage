#!/bin/bash

set -ex

print_usage() {
    cat <<EOF
usage: $0 [prepare|deb|rebuild]

prepare: only prepare a source repo of FreeCAD Link branch
deb: build deb package using pbuilder
rebuild: delete any previously built source and binary package, and rebuild

Default behavior is to make sure repo is up to date, and deb package is built,
and then build the AppImage.

If everything runs fine, the final AppImage will be located at img sub
directory.
EOF
}

img_name=${IMG_NAME:=img}

repo_url=${REPO_URL:=https://github.com/FreeCAD/FreeCAD}
repo_branch=${REPO_BRANCH:=master}

dpkg_url=${DPKG_URL:=https://git.launchpad.net/~freecad-maintainers/+git/gitpackaging}
dpkg_branch=${DPKG_BRANCH:=dailybuild-occt}

aimg_url=${AIMG_URL:=https://github.com/realthunder/AppImages.git}
aimg_branch=${AIMG_BRANCH:=master}
aimg_recipe=recipe.yml

mkdir -p build/$img_name
cd build/$img_name

debfile=$HOME/pbuilder/trusty_result/freecad-daily*amd64.deb
dscfile=$PWD/freecad*.dsc

build=2
cmd=$1
if test $cmd; then
    case "$1" in
        rebuild)
            rm -f $dscfile* $debfile
            ;;
        prepare)
            build=0
            ;;
        deb)
            build=1
            ;;
        *)
            print_usage
            exit 1
    esac
fi

git_fetch() {
    local dir=$1
    local url=$2
    local branch=$3
    if ! test -d $dir; then
        git clone -b $branch --depth 1 --single-branch $url $dir
        pushd $dir
    else
        pushd $dir
        git fetch origin $branch
        git checkout -qf FETCH_HEAD
    fi
    hash=$(git show -s --format=%H)
    popd
}

# prepare freecad repo
git_fetch repo $repo_url $repo_branch
# save the last commit hash
repo_hash=$hash
# export shortend repo hash for later use during installation
export REPO_HASH=${hash:0:8}

# perform a freecad cmake configure to obtain the version header
mkdir -p repo/build
pushd repo/build
cmake ..
cp ./src/Build/Version.h ../src/Build/
popd
rm -rf repo/debian

# prepare debain packaging repo
git_fetch packaging $dpkg_url $dpkg_branch
# obtain packaging repo last commit hash
pkg_hash=$hash

# copy packaging directory to freecad repo
cp -a packaging/debian repo/

# make sure the source package are (re)built if anything has changed
if ! test -f $dscfile ||
   ! read rhash phash &>/dev/null < $dscfile.hash || \
   [ "$rhash" != $repo_hash ] || \
   [ "$phash" != $pkg_hash]; 
then
    rm -f $dscfile
    cd repo
    echo y | debuild -S -d -us -uc
    cd ..
    echo "$repo_hash $pkg_hash" > $dscfile.hash
fi

dsc_date=`date -r $dscfile +%Y%m%d%H%M`

if [ $build -gt 0 ]; then
    deb_date=0
    if test -f $debfile; then
        deb_date=`date -r $debfile +%Y%m%d%H%M`
    fi
    if [ $deb_date -lt $dsc_date ]; then
        pbuilder_dir=$HOME/pbuilder/trusty_result
        mkdir -p $pbuilder_dir/old
        mv $pbuilder_dir/freecad-daily* $pbuilder_dir/old/ || true
        pbuilder-dist trusty build $dscfile
    fi
fi

if [ $build -gt 1 ]; then
    # copy the recipe, and customize the name
    cp ../../$aimg_recipe .
    sed -i "s/#NAME#/$img_name/g" $aimg_recipe

    # prepare AppImages repo
    git_fetch AppImages $aimg_url $aimg_branch
    cd AppImages
    # now generate the AppImage using the recipe
    bash -ex ./pkg2appimage ../$aimg_recipe
    mv out/FreeCAD-$img_name* ../../
fi

