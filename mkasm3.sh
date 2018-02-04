#!/bin/bash

export FMK_IMG_NAME=asm3

# yes, I am using a local git repo for speed, better using absolute path
export FMK_REPO_URL=https://github.com/realthunder/FreeCAD

export FMK_REPO_BRANCH=LinkStage3

# One additional work bench to install
export FMK_WB_LIST=asm3

# again, this is a local git repo
export FMK_WB_URL_asm3=https://github.com/realthunder/FreeCAD_assembly3

# asm3 is a new style module, so install to Ext directory.
export FMK_WB_PATH_asm3=Ext/freecad

# one submodule needed to be checked out
export FMK_WB_SUB_asm3=py_slvs

./mkimg.sh $@
