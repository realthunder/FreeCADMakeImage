#!/bin/bash

if ! test -d build/conda; then
    mkdir -p build/conda/env
    pushd build/conda
    wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
    chmod +x Miniconda3-latest-Linux-x86_64.sh
    ./Miniconda3-latest-Linux-x86_64.sh -b -p ./env
    . env/bin/activate
    conda config --add channels conda-forge
    conda config --append channels freecad
    conda instal conda-build
else
    pushd build/conda
    . env/bin/activate
fi
popd

