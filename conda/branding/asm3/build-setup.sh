#!/bin/bash

set -e

src=$1
repo=$2
if ! cmp -s $src/icon.ico $repo/src/Main/icon.ico; then
    cp $src/icon.ico $repo/src/Main/
fi
