#!/bin/bash

export FMK_IMG_NAME=asm3

export FMK_REPO_URL=https://github.com/realthunder/FreeCAD
export FMK_REPO_BRANCH=LinkStage3

# One additional work bench to install
export FMK_WB_LIST=asm3
# one submodule needed to be checked out
export FMK_WB_SUB_asm3=py_slvs

export FMK_WB_URL_asm3=https://github.com/realthunder/FreeCAD_assembly3

# asm3 is a new style module, so install to Ext directory.
export FMK_WB_PATH_asm3=Ext/freecad

if [ "$1" = 'branch' ]; then
    shift
    export FMK_REPO_BRANCH=$1
    shift
    export FMK_WB_BRANCH_asm3=$1
    shift
    export FMK_WB_SUB_asm3=$1
    shift
fi

./mkimg.sh $@
