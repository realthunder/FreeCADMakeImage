#!/bin/bash

export FMK_IMG_NAME=asm3

export FMK_REPO_URL=https://github.com/realthunder/FreeCAD
export FMK_REPO_BRANCH=LinkStage3

# One additional work bench to install
export FMK_WB_LIST="asm3 py3_slvs"
# submodules needed to be checked out
export FMK_WB_SUB_asm3="py_slvs"
export FMK_WB_URL_asm3=https://github.com/realthunder/FreeCAD_assembly3
# asm3 is a new style module, so install to Ext directory.
export FMK_WB_PATH_asm3=Ext/freecad

# install solverspace python 3 prebuilt separately as it uses different branch
# for different python minor version
export FMK_WB_URL_py3_slvs=https://github.com/realthunder/py3_slvs
export FMK_WB_BRANCH_py3_slvs=py36
export FMK_WB_PATH_py3_slvs=Ext/freecad/asm3
# Do not include rev of this repo into the final version
export FMK_WB_VER_py3_slvs=0

if [ "$1" = 'branch' ]; then
    shift
    export FMK_REPO_BRANCH=$1
    shift
    export FMK_WB_BRANCH_asm3=$1
    shift
    export FMK_WB_SUB_asm3=$1
    shift
fi

if [ "$1" = 'mac' ]; then
    shift
    export FMK_WB_SUB_asm3=py_slvs_mac
fi

./mkimg.sh $@
