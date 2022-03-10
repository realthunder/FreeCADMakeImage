#!/bin/bash

test "$FMK_BRANDING" || export FMK_BRANDING=asm3
test "$FMK_IMG_NAME" || export FMK_IMG_NAME=asm3
test "$FMK_REPO_URL" || export FMK_REPO_URL=https://github.com/realthunder/FreeCAD
test "$FMK_REPO_BRANCH" || export FMK_REPO_BRANCH=LinkStage3

# additional workbench to install
if test -z "$FMK_WB_LIST"; then
    # export FMK_WB_LIST="asm3 py3_slvs"
    export FMK_WB_LIST="asm3"
    test "$FMK_WB_PATH_asm3" || export FMK_WB_PATH_asm3=Mod
    test "$FMK_WB_URL_asm3" || export FMK_WB_URL_asm3=https://github.com/realthunder/FreeCAD_assembly3
    # submodules needed to be checked out
    # test "$FMK_WB_SUB_asm3" || export FMK_WB_SUB_asm3="py_slvs"

    # install solverspace python 3 prebuilt separately as it uses different branch
    # for different python minor version
    test "$FMK_WB_URL_py3_slvs" || export FMK_WB_URL_py3_slvs=https://github.com/realthunder/py3_slvs
    test "$FMK_WB_BRANCH_py3_slvs" || export FMK_WB_BRANCH_py3_slvs=py36
    test "$FMK_WB_PATH_py3_slvs" || export FMK_WB_PATH_py3_slvs=Mod/asm3/freecad/asm3
    # Do not include revision md5 of this repo into the final version
    test "$FMK_WB_VER_py3_slvs" || export FMK_WB_VER_py3_slvs=0

    args=
    mac=
    conda=
    for arg in "$@"; do
        case $arg in
        mac)
            # export FMK_WB_SUB_asm3=py_slvs_mac
            mac=1
            continue
            ;;
        conda)
            conda=1
            export FMK_WB_SUB_asm3=
            export FMK_WB_LIST=asm3
            ;;
        esac
        args="$args $arg"
    done
    if test -z $mac && test $conda; then
        export FMK_WB_LIST="$FMK_WB_LIST appimage_updater"
        export FMK_WB_PATH_appimage_updater=Mod
        export FMK_WB_URL_appimage_updater=https://github.com/looooo/freecad.appimage_updater.git
    fi
else
    args="$@"
fi

./mkimg.sh $args
