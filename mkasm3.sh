#!/bin/bash

export IMG_NAME=asm3

# yes, I am using a local git repo for speed, better using absolute path
export REPO_URL=https://github.com/realthunder/FreeCAD

export REPO_BRANCH=LinkStage3

# One additional work bench to install
export WB_LIST=asm3

# again, this is a local git repo
export WB_URL_asm3=https://github.com/realthunder/FreeCAD_assembly3

# asm3 is a new style module, so install to Ext directory.
export WB_PATH_asm3=Ext/freecad

# one submodule needed to be checked out
export WB_SUB_asm3=py_slvs

./mkimg.sh
