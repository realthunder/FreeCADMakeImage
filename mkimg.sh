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

remote=
if [ "$1" = remote ]; then
    shift
    # expect remote followed by <host>:<path>
    remote=$1
    shift
fi

dpkg_branch=xenial
aimg_recipe=recipe.yml

conda=
build=2
args="$@"
while test $1; do
    case "$1" in
        conda)
            conda=1
            ;;
        rebuild)
            rm -rf build/$img_name
            ;;
        prepare)
            build=0
            ;;
        build)
            build=1
            ;;
        package)
            build=3
            ;;
        bionic)
            aimg_recipe=recipe-bionic.yml
            dpkg_branch=bionic
            ;;
        *)
            print_usage
            exit 1
    esac
    shift
done

img_name=${FMK_IMG_NAME:=img}

repo_url=${FMK_REPO_URL:=https://github.com/FreeCAD/FreeCAD}
repo_branch=${FMK_REPO_BRANCH:=master}

dpkg_url=${FMK_DPKG_URL:=https://github.com/realthunder/fcad-packaging.git}
dpkg_branch=${FMK_DPKG_BRANCH:=$dpkg_branch}

aimg_url=${FMK_AIMG_URL:=https://github.com/realthunder/AppImages.git}
aimg_branch=${FMK_AIMG_BRANCH:=master}
aimg_recipe=${FMK_AIMG_RECIPE:=$aimg_recipe}


if test $remote; then
    host=${remote%:*}
    path=${remote#*:}
    if test -z $host || [ "$path" = "$host" ]; then
        echo "invalid remote host or path"
        exit 1
    fi

    # cd to the directory containing this script
    dir="`dirname "${BASH_SOURCE[0]}"`"
    cd $dir

    if test "$FMK_VERSION_HEADER"; then
        if ! test -f "$FMK_VERSION_HEADER"; then
            echo "Cannot find version header: $FMK_VERSION_HEADER"
            exit 1
        fi
        cp -f "$FMK_VERSION_HEADER" ./Version.h
        export FMK_VERSION_HEADER="../../Version.h"
    fi

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
            echo "export ${line%=*}=\"${line#*=}\"" >> tmp.sh
        fi
    done
    set -x
    echo "./mkimg.sh $args" >> tmp.sh

    # pipe current directory (excluding the build directory) through
    # tar -> ssh -> remote tar, and then run the script remotely
    find . \( -path ./build -o -path ./.git \) -prune -o -print0 |
        tar --exclude='./build' --exclude './.git' -c --null -T - |
        ssh $host -C "mkdir -p $path;cd $path;tar xvf -;./tmp.sh $@"

    [ $build -gt 1 ] || exit

    # tar pipe back the result and clean the remote computer
    ssh $host "cd $path/build/out && tar cf - . && rm -rf *" | tar xvf - -C ./build/out
    exit
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
        hash=$(git show -s --format=%H)
        remote_hash=$(git ls-remote $url $branch | awk '{ print $1 }')
        if [ "$hash" != "$remote_hash" ]; then
            git fetch --depth=1 origin $branch
            git checkout -qf FETCH_HEAD
        fi
    fi
    hash=$(git show -s --format=%H)
    popd
}

if test $conda; then
    img_name=conda
fi

mkdir -p build/$img_name
cd build/$img_name

# prepare freecad repo
git_fetch repo $repo_url $repo_branch

if test "$FMK_VERSION_HEADER"; then
    if ! test -f "$FMK_VERSION_HEADER"; then
        echo "Cannot find version header: $FMK_VERSION_HEADER"
        exit 1
    fi
    if ! cmp -s "$FMK_VERSION_HEADER" repo/src/Build/Version.h; then
        cp -f $FMK_VERSION_HEADER repo/src/Build/Version.h
    fi
else
    rm -f repo/src/Build/Version.h
fi

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
        # url=${FMK_LIBPACK_URL:=https://github.com/sgrogan/FreeCAD/releases/download/0.17-med-test/FreeCADLibs_11.5.3_x64_VC12.7z}
        url=${FMK_LIBPACK_URL:=https://github.com/FreeCAD/FreeCAD-ports-cache/releases/download/v0.18/FreeCADLibs_11.11_x64_VC12.7z}
        wget -c $url -O libpack.7z
        7z x libpack.7z
        mv FreeCADLibs* libpack
    fi
    popd

    mkdir -p tmp
    rm -rf tmp/* FreeCAD-*-Win64

    mkdir -p repo/build
    pushd repo/build
    libpack=../../../libpack
    if ! test -f FreeCAD_trunk.sln; then
        "$cmake" .. -DFREECAD_LIBPACK_DIR=$libpack  \
            -DOCC_INCLUDE_DIR=$libpack/include/opencascade -G "Visual Studio 12 2013 Win64"
    fi
    if ! test -d bin; then
        set +x
        dir=$PWD
        pushd $libpack/bin
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
    
    if test -f ../src/Build/Version.h && \
        ! cmp -s ../src/Build/Version.h src/Build/Version.h; then
        rm -rf src/Build/*
        mkdir -p src/Build
        cp ../src/Build/Version.h src/Build
    fi

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

# building for mac
if [ $(uname) = 'Darwin' ]; then
    export CXX=clang++
    export CC=clang
    export PATH=/usr/lib/ccache:/usr/local/bin:$PATH

    mkdir -p repo/build
    pushd repo/build

    QT5_CMAKE_PREFIX=$(ls -d $(brew --cellar)/qt/*/lib/cmake)
    QT5_WEBKIT_CMAKE_PREFIX=$(ls -d $(brew --cellar)/qtwebkit/*/lib/cmake)
    INSTALL_PREFIX="../../tmp"
    mkdir -p "$INSTALL_PREFIX"

   if ! read rhash &>/dev/null < .configure.hash || [ "$rhash" != $repo_hash ]; then
        cmake \
        -DCMAKE_BUILD_TYPE="Release"   \
        -DBUILD_QT5=1                  \
        -DCMAKE_PREFIX_PATH="${QT5_CMAKE_PREFIX};${QT5_WEBKIT_CMAKE_PREFIX}"  \
        -DFREECAD_USE_EXTERNAL_KDL=1   \
        -DBUILD_FEM_NETGEN=1           \
        -DFREECAD_CREATE_MAC_APP=1     \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"  \
        ../

        echo "$repo_hash" > .configure.hash
    fi
    [ $build -gt 0 ] || exit

    ncpu=$(sysctl hw.ncpu | awk '{print $2}')
    [ "$ncpu" != "1" ] || ncpu=2

    do_build=
    if ! read rhash &>/dev/null < .build.hash || [ "$rhash" != $repo_hash ]; then
        do_build=1
    fi
    if test $do_build; then
        if test -f ../src/Build/Version.h && \
            ! cmp -s ../src/Build/Version.h src/Build/Version.h; then
            rm -rf src/Build/*
            mkdir -p src/Build
            cp ../src/Build/Version.h src/Build
        fi
        make -j$ncpu
        echo "$repo_hash" > .build.hash
    fi

    [ $build -gt 1 ] || exit

    do_install=
    if ! read rhash &>/dev/null < .install.hash || [ "$rhash" != $repo_hash ]; then
        do_install=1
    fi
    test -z $do_install || make -j$ncpu install
    echo "$repo_hash" > .install.hash

    APP_PATH="$INSTALL_PREFIX/FreeCAD.app"
    export FMK_WB_BASE_PATH="$APP_PATH/Contents"
    export FMK_REPO_VER_PATH="$INSTALL_PREFIX/VERSION"

    ../../../../installwb.sh

    name=FreeCAD-`cat $INSTALL_PREFIX/VERSION`-OSX-x86_64-Qt5
    echo $name
    rm -f ../../../out/$name.dmg
    hdiutil create -fs HFS+ -srcfolder "$APP_PATH" ../../../out/$name.dmg
    exit
fi

# building for linux

if test $conda; then
    docker_name="conda-forge"
    conda_img_name="FreeCAD-asm3-Conda_Py3Qt5_glibc2.12-x86_64"
    if [ $build -ne 3 ]; then
        sudo docker start $docker_name && \
            sudo docker exec -u conda -t -i -w /home/conda/projects/FreeCADMakeImage/conda/freecad_asm3 \
                $docker_name /bin/bash -c "/opt/conda/bin/conda build ."
    fi
    if [ $build -gt 1 ]; then
        rm -rf wb/*
        mkdir -p wb
        FMK_WB_BASE_PATH=wb ../../installwb.sh
        sudo docker start $docker_name && \
            sudo docker exec -u conda -t -i -w /home/conda/ \
                $docker_name /bin/bash -c \
                    "source /opt/conda/etc/profile.d/conda.sh && \
                     export FMK_CONDA_IMG_NAME=$conda_img_name && \
                     export FMK_CONDA_FC_EXTRA=/home/conda/projects/FreeCADMakeImage/build/conda/wb && \
                     projects/FreeCADMakeImage/conda/install.sh" && \
            sudo docker cp $docker_name:/home/conda/$conda_img_name.AppImage ../out 
    fi
    exit
fi

if [ $build -ne 3 ]; then
    # prepare debain packaging repo
    rm -rf packaging
    git_fetch packaging $dpkg_url $dpkg_branch
    # obtain packaging repo last commit hash
    pkg_hash=$hash

    # copy packaging directory to freecad repo
    cp -a packaging/debian repo/

    pushd repo
    ncpu=$(grep -c ^processor /proc/cpuinfo)
    DEB_BUILD_OPTIONS="parallel=$ncpu" debuild -b -us -uc
    popd
fi

if [ $build -gt 1 ]; then
    # copy the recipe, and customize the name
    cp ../../$aimg_recipe .
    sed -i "s/#NAME#/$img_name/g" $aimg_recipe

    # prepare AppImages repo
    git_fetch AppImages $aimg_url $aimg_branch
    cd AppImages
    # now generate the AppImage using the recipe
    DEBDIR="$PWD/.." ARCH=x86_64 ./pkg2appimage ../$aimg_recipe
    mv out/FreeCAD-$img_name*.AppImage ../../out/
fi

