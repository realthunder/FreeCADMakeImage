#!/bin/bash

set -ex

print_usage() {
    cat <<EOF
usage: $0 [remote <host:path>] [rebuild|prepare|build]

remote: copy this repository through ssh to host:path, and then run on remote
        host

rebuild: delete any previously built source and binary package, and rebuild

prepare: only prepare a source repo of FreeCAD Link branch

build: build deb package with pbuilder, or on Windows build with cmake --build

If no [rebuild|prepare|build] specified, the default behavior is to make sure
repo is up to date, and deb package is built, and then build the AppImage.

If everything runs fine, the final result will be located at build/out
EOF
}

mkdir -p build/out

if [ "$1" = remote ]; then
    shift
    # expect remote followed by <host>:<path>
    remote=$1
    shift
    host=${remote%:*}
    path=${remote#*:}
    if test -z $host || [ "$path" = "$host" ]; then
        echo "invalid remote host or path"
        exit 1
    fi

    # cd to the directory containing this script
    dir="`dirname "${BASH_SOURCE[0]}"`"
    cd $dir

    # obtain the base directory name of this script, and
    # append it to remote <path>
    base=`basename "$PWD"`
    if test $path; then
        path=$path/$base
    else
        path=$base
    fi

    # create a temperary script and export all the environment variables
    echo "#!/bin/bash" > tmp.sh
    chmod +x tmp.sh
    set +x
    env | while read -r line; do
        if [ "${line:0:4}" = FMK_ ]; then
            echo export $line >> tmp.sh
        fi
    done
    set -x
    echo './mkimg.sh $@' >> tmp.sh

    # find all regular file under the current directory, pipe them through
    # tar -> ssh -> remote tar, and then run the script remotely
    find . -maxdepth 1 -type f -print0 |
        tar -c --null -T - |
        ssh $host -C "mkdir -p $path;cd $path;tar xvf -;./tmp.sh $@"

    [ $build -gt 1 ] || exit

    # rsync back the result
    rsync -acvrt -e ssh $host:$path/build/out/ ./build/out/
    exit
fi

img_name=${FMK_IMG_NAME:=img}

repo_url=${FMK_REPO_URL:=https://github.com/FreeCAD/FreeCAD}
repo_branch=${FMK_REPO_BRANCH:=master}

dpkg_url=${FMK_DPKG_URL:=https://git.launchpad.net/~freecad-maintainers/+git/gitpackaging}
dpkg_branch=${FMK_DPKG_BRANCH:=dailybuild-occt}

aimg_url=${FMK_AIMG_URL:=https://github.com/realthunder/AppImages.git}
aimg_branch=${FMK_AIMG_BRANCH:=master}
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
            rm -f $dscfile* $debfile repo/build/bin
            ;;
        prepare)
            build=0
            ;;
        build)
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
export FMK_REPO_HASH=${hash:0:8}

# check for windows building
if [ "$PROGRAMFILES" != "" ]; then 
    pushd ../
    if [ "$PROCESSOR_ARCHITECTURE" != "AMD64" ]; then
        echo "only support building on Windows x64"
        exit 1
    fi

    echo 'building for windows...'

    cmake=${FMK_CMAKE_EXE:=`echo /cygdrive/c/program\ files/*/bin/cmake.exe`}
    if ! test -e "$cmake"; then
        echo "CMAKE_EXE not set properly"
        exit 1
    fi

    if ! test -d libpack; then
        url=${FMK_LIBPACK_URL:=https://github.com/sgrogan/FreeCAD/releases/download/0.17-med-test/FreeCADLibs_11.5.3_x64_VC12.7z}
        wget -c $url -O libpack.7z
        7z x libpack.7z
        mv FreeCADLibs* libpack
    fi
    popd

    mkdir -p tmp
    rm -rf tmp/* FreeCAD-*-Win64

    mkdir -p repo/build
    pushd repo/build
    if ! test -f FreeCAD_trunk.sln; then
        "$cmake" .. -DFREECAD_LIBPACK_DIR=../../../libpack -G "Visual Studio 12 2013 Win64"
    fi
    if ! test -d bin; then
        set +x
        dir=$PWD
        pushd ../../../libpack/bin
        exclude=bin_exclude.lst
        rm -f $exclude
        echo "generate exclude file list..."
        find . -name '*.*' -print0 |
        while IFS= read -r -d '' file; do
            # filter <prefix>d.<ext> if <prefix>.<ext> exists
            #    or <prefix>_d.<ext> if <prefix>.<ext> exists
            #
            # TODO: this two conditions should be able to shorten using
            # optional character matching in regex, e.g. ${file%%?(_)d.dll}.
            # Strangely, it works only in terminal but not in script! Why??!!

            ext="${file: -3}"
            if [ "${file%-gd-*\.dll}" != "$file" ] || \
               test -f ${file%[Dd]\.$ext}.$ext || \
               test -f ${file%_[Dd]\.$ext}.$ext;
            then
                echo "$file" >> $exclude
            fi
        done
        echo "copying bin directory..."
        mkdir -p $dir/bin
        tar --exclude 'h5*.exe' --exclude 'Qt*d4.dll' --exclude 'swig*' --exclude "*.pyc" \
            --exclude 'boost*-gd-*.dll' --exclude "*.pdb" -X $exclude -cf - . |
            (cd $dir/bin && tar xvBf -)
        set -x

        popd
    fi

    [ $build -gt 0 ] || exit
    
    # get cpu core count
    ncpu=$(grep -c ^processor /proc/cpuinfo)

    # start building
    "$cmake" --build . --config Release -- /maxcpucount:$ncpu

    [ $build -gt 1 ] || exit

    # copy out the result to tmp directory
    tar --exclude '*.pyc' -cf - bin Mod Ext data | (cd ../../tmp && tar xvBf -)
    cd ../../tmp

    # install personal workbench. This script will write version string to
    # ../VERSION file
    ../../../installwb.sh
    cd ..
    name=FreeCAD-`cat VERSION`-Win64

    # archive the result
    mv tmp $name
    7z a ../out/$name.7z $name

    exit
fi

# building for linux

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
    mv out/FreeCAD-$img_name*.AppImage ../../out/
fi

