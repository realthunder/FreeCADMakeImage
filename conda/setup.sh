test "$conda_host" || conda_host=MacOSX
test "$conda_path" || conda_path=env

conda_cmd=
if test -e $conda_path/bin/conda; then
    source $conda_path/etc/profile.d/conda.sh
else
    rm -rf $conda_path
    curl -C - -L -O https://repo.continuum.io/miniconda/Miniconda3-latest-$conda_host-x86_64.sh
    bash Miniconda3-latest-$conda_host-x86_64.sh -b -p ./$conda_path
    source $conda_path/etc/profile.d/conda.sh
    conda config --add channels conda-forge
    conda config --append channels freecad
    conda install conda-build -y
fi

conda_host_ver=${FMK_CONDA_MAC_HOST_VER:="10.13"}
conda_sdk_ver=${FMK_CONDA_MAC_SDK_VER:="10.12"}
conda_sdk_dir=opt/MacOSX$conda_sdk_ver.sdk
if ! test -d $conda_sdk_dir; then
    curl -C - -L -O https://github.com/phracker/MacOSX-SDKs/releases/download/$conda_host_ver/MacOSX$conda_sdk_ver.sdk.tar.xz
    mkdir -p opt
    tar -C opt -xf MacOSX$conda_sdk_ver.sdk.tar.xz
fi

cat > conda_build_config.tmp << EOS
CONDA_BUILD_SYSROOT:
- $PWD/$conda_sdk_dir  # [osx]
MACOSX_DEPLOYMENT_TARGET:
- 10.10
EOS
if ! cmp -s conda_build_config.tmp conda_build_config.yaml; then
    cp conda_build_config.tmp conda_build_config.yaml
fi
conda_cmd="conda build -e $PWD/conda_build_config.yaml "

