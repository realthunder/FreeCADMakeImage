# Overview

This repository contains some helper scripts to locally build personalized
[FreeCAD](https://github.com/FreeCAD/FreeCAD) release image, making it easy
to release feature testing images.

The most import script for building all type of images is [mkimg](./mkimg.sh).
You can find detailed script usage instruction [here](./mkimg.sh#L7) or by
running,

```
./mkimg.sh help
```

More customization of the script is done using various 
[environment variables](#environment-variables).

# Linux

Linux image is packaged using [AppImage](https://appimage.org/). The
[mkimg](./mkimg.sh) script supports building the package using either 
[debian](https://en.wikipedia.org/wiki/Deb_(file_format)) or 
[conda](https://docs.conda.io/en/latest/) packaging.

## Debian

When using `debian`, the script first clone a git repo of FreeCAD source
code, clone another repo holding `debian` packaging directory, build the `deb`
package, and finally create the `AppImage` using that `deb` package. The script
supports building `debian` package on both Ubuntu `Xenial` and `Bionic`. The
`Xenial` package only support `Python 2` with `Qt 4`, while `Bionic` will build
and install both `Python 2 and 3` with `Qt 5`. One thing to note is that the
`Bionic` uses a newer `glibc`, so its `AppImage` can only run on system
with `glibc >= 2.2`.

> Note: If you have FreeCAD repository already cloned, you can reuse your download as follows: 
> ```
> mv /path/to/FreeCAD build/<FMK_IMG_NAME>/repo
> ```

If your host is either `Xenial` or `Bionic`, you can run the script natively.
To install the build dependencies, run the following script,

```
cd docker && ./setup.sh <dist>_deps.sh
```

Replace `<dist>` with either `bionic` or `xenial`. After that, to build
natively on `Xenial`, run

```
./mkimg.sh dist=xenial
```

If no `dist` argument is given, it builds for `Bionic`.

If you are running other Linux distributions, you can use docker for building.
You'll need to install docker for your distribution first. For ubuntu

```
apt get docker.io
```

To build `Bionc` image with docker, run

```
./mkimg.sh dist=bionic docker sudo
```

In case you have setup running docker without `sudo`, you can omit the `sudo`
argument above. The first time you run `mkimge.sh` for docker build, it will
create a image and pre-install all build dependency, which will take some extra
time.

The docker container runs build script under user `freecad`. The build
environment is located at `build/docker/<FMK_IMG_NAME>`. This directory is
mapped into docker container as `/home/freecad/works`. This makes it possible
to preserve the build output for faster incremental build, even though the
docker container is ran with `--rm`, meaning that it will be auto removed on
exit. You'll need around 13GiB free space for `Bionic` build. You can safely
delete everything under `build/docker` once build is done and no longer need
further testing. The resulting `AppImage` is located in `build/out`.

## Linux Conda

When using `conda`, it uses `conda-forge` docker
[image](https://github.com/conda-forge/docker-images/tree/master/linux-anvil-comp7).
The reason for using docker instead of native `miniconda` is because of `conda`
Linux package's requirement of linking to a `Centos 6` specific version of
`opengl` library. 

To run `conda` build,

```
./mkimg.sh conda sudo
```

Again, you do not need `sudo` if you have setup docker to run without `sudo`. The
first time the script is ran, it will create a docker image with all build
dependencies, which will take extra time. The docker container is ran under
user `conda`. But unlike debian docker build environment, `conda` docker
environment maps the entire script directory. Your build directory is located
at `build/conda/<FMK_IMG_NAME>/conda-bld/freecad-<FMK_IMG_NAME>_<timestamp>/work/build`.
The build directory is preserved across multiple runs to accelerate subsequent
build. To build from scratch, run

```
./mkimg.sh rebuild conda sudo
```

Note that when rebuilding, the build directory with an older time stamp will
be left over, and one with newer time stamp will be created. You may want to
manually remove the older one to free up disk space.

To clean build environment, simply delete `build/conda/<FMK_IMG_NAME>` directory.

# Windows

The [mkimg](./mkimg.sh) script also supports building for Windows. For `Python 2`
build, you need to install `Visual Studio 2013`. For `Python 3`, you can install
[Visual Studio 2017 Build Tools](https://visualstudio.microsoft.com/vs/older-downloads/). 
Make sure you select VC++ compile and Windows 10 SDK during installation.

* [CMake] is no longer required to install before hand. The script will choose
  and download the proper version of `CMake` depending on your build selection.

* [cygwin](https://cygwin.com/install.html). It is only used in order to run
  the scripts here. Make sure you select the following packages,
    * p7zip
    * git
    * wget
    * tar
    * rsync
    * openssh, optional. Only needed if you want to build on remote machine.

To build `Python 2 with Qt 4`, simply run

```
./mkimg.sh
```

To build `Python 3 with Qt 5`, run

```
./mkimg.sh py3
```

# Mac OSX

The script is also tested to be working on OSX Seirra (10.12) and High Seirra
(10.13). 

## Mac OSX Python 2

To build `Python 2` version of App bundle for Mac OSX, you'll first need
to install the dependency using [homebrew](https://brew.sh/). If you haven't
install homebrew yet, run the following command in a terminal,

```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Then install the dependencies

```
brew tap freecad/freecad
brew install eigen
brew install --only-dependencies freecad --with-packaging-utils
```

Then run

```
./mkimg.sh
```

## Mac OSX Python 3

FreeCAD `Python 3` binary on Mac OSX is built using `conda`. The script will
install and run `conda` natively. The `conda` environment is installed in
`build/conda/<FMK_IMG_NAME>/env` directory. The bundled `conda freecad_asm3`
[recipe](./conda/meta.yaml) uses the latest `conda` Qt 5.9, which require
MacOSX SDK >= 10.12. However, some `conda` pre-built package seems to pull in
hard coded SDK dependency, which causes build to fail unless you create
a symlink of name `MacOSX10.9.SDK` in
`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/`
pointing to the actual SDK directory you are using. `mkimg.sh` will
download and extract the SDK in `build/conda/<FMK_IMG_NAME>/opt/MacOSX10.12.sdk`.
Run the following command to create the symlink, assuming you are at the
same directory as `mkimg.sh` and your `FMK_IMG_NAME` is set to `img` which is
the default value.

```
mkdir -p /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
ln -s $PWD/build/conda/img/opt/MacOSX10.12.sdk \
    /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk
```

Then build with

```
./mkimg.sh conda
```

The build directory is located at 
`build/conda/<FMK_IMG_NAME>/env/conda-bld/freecad_<FMK_IMG_NAME>-<timestamp>/work/build`.

# Environment Variables

You can configure the [mkimg](./mkimg.sh) script with a list of environment
variables. It will be easier to write a wrapper script together with the 
configuration. For example, the [mkasm3](./mkasm3.sh) script  will build my 
[fork](https://github.com/realthunder/FreeCAD/tree/LinkStage3) of FreeCAD, 
and pre-install the [Assembly3](https://github.com/realthunder/FreeCAD_assembly3)
workbench. 

The supported environment variables are listed as follow, most of which are
optional and has default value as shown in the bracket.

- **FMK_IMG_NAME** (`img`), name to be appeared in the file name of AppImage
  final output. It is also used as the name for the local build directory.
- **FMK_REPO_URL** (https://github.com/FreeCAD/FreeCAD), the git URL of your
  FreeCAD repo.
- **FMK_REPO_BRANCH** (`master`), branch, tag, or commit of the git repo to
  checkout.
- **FMK_REPO_VER** (`1`), set to 1 to include the git checkout hash to the file
  name of AppImage final output.
- **FMK_DPKG_URL**
  (https://github.com/realthunder/fcad-packaging.git), the git URL of Debian
  package repo.
* **FMK_VERSION_HEADER** (`none`), path to Version.h file containing the version
  number to be appear in FreeCAD about page.
- **FMK_DPKG_BRANCH** (`bionic` or `xenial` depending on current `dist`), the
  git branch of the Debian package repo.
- **FMK_AIMG_URL** (https://github.com/realthunder/AppImages.git), the git URL
  of AppImage script repo.
- **FMK_AIMG_BRANCH** (`master`), the git branch of the AppImage repo
- **FMK_WB_LIST**, space delimited name list of personal workbenches to
  install. The name will also be used for the local installation directory.
- **FMK_WB_URL_`<name>`**: the git URL of the workbench named `<name>`
- **FMK_WB_BRANCH_`<name>`** (`master`) branch, tag, or commit of the workbench
  named `<name>` to checkout
- **FMK_WB_VER_`<name>`** (`1`), set to 1 to include the git checkout hash of
  the workbench named `<name>` to the file name of AppImage final output.
- **FMK_WB_PATH_`<name>`** (`Mod`), path relative to FreeCAD installation
  directory to install the workbench named `<name>`
- **FMK_WB_SUB_`<name>`**, a list of submodule names to checkout
* Windows related variables
    * FMK_LIBPACK_URL
      (for python 2, https://github.com/FreeCAD/FreeCAD-ports-cache/releases/download/v0.18/FreeCADLibs_11.11_x64_VC12.7z,
       for python 3, https://github.com/FreeCAD/FreeCAD/releases/download/0.19_pre/FreeCADLibs_12.1.2_x64_VC15.7z)
      URL to download FreeCAD library pack for Windows.

Once you've configured all the variables, simply run

```
./mkimg.sh
```

The script can also be ran remotely. It copies itself to the remote machine
through ssh and then run from there. I use it to build on remote Windows
machine from Linux. Assuming the remote machine has all the required software
setup properly, run

```
./mkimg.sh remote=<host>:<remote_path>
```

The remote host and path follows the `scp` usage convention.

