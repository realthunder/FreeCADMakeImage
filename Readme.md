# Overview

This repository contains some helper scripts to locally build personalized
[FreeCAD](https://github.com/FreeCAD/FreeCAD) release image, making it easy
to release feature testing images.

# AppImage

The [mkimg](./mkimg.sh) script is to prepare and build a Debian package from
a given FreeCAD git repository, and then build an [AppImage](https://appimage.org/) 
with optional pre-installation of any given external workbenches

## Setup `pbuilder`

You need to setup [pbuilder](https://wiki.ubuntu.com/PbuilderHowto) before
being able to build a Debian package independent of your own system using
`pbuilder-dist`. 

First, run

```
sudo apt install gnupg pbuilder ubuntu-dev-tools apt-file eatmydata
```

Since AppImage has better support for trusty, we shall stick to that. So we
create a `pbuilder` trusty distribution, 

```
pbuilder-dist create trusty 
```

Create a file `~/.pbuilderrc` with the following content

```
OTHERMIRROR="deb http://ppa.launchpad.net/freecad-maintainers/freecad-daily/ubuntu trusty main"
PTCACHEHARDLINK=no
CCACHEDIR=/var/cache/pbuilder/ccache
PACKAGES=eatmydata
EATMYDATA=yes
```

Login to `pbuilder` to change a few setting,

```
pbuilder-dist trusty login --save-after-login
```

You have just entered a `chroot` environment. Now, install 
[eatmydata](http://manpages.ubuntu.com/manpages/artful/man1/eatmydata.1.html)
for better performance. Note that we've already installed `eatmydata` in the
host machine in previous step, but we still need to install the same package in
the `chroot` virtual environment for it to work.

```
sudo apt install eatmydata
```

Add key for `freecad-daily ppa`, and exit

```
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 83193AA3B52FF6FCF10A1BBF005EAE8119BB5BCA
exit 
```

Update `pbuilder` source list

```
pbuilder-dist trusty update --release-only
```

## Script Usage

You can configure the [mkimg](./mkimg.sh) script with a list of environment
variables. It will be easier to write a wrapper script together with the 
configuration. For example, the [mkasm3](./mkasm3.sh) script  will build my 
[fork](https://github.com/realthunder/FreeCAD/tree/LinkStage3) of FreeCAD, 
and pre-install the [Assembly3](https://github.com/realthunder/FreeCAD_assembly3)
workbench. Note that mkimg uses `pbuilder-dist`, which requires root privilege 
when satisfying build dependency, which means that it will prompt for password.
It's kind of annoying, but seems to be hard to
[workaround](https://pbuilder.alioth.debian.org/#nonrootchroot).

The supported environment variables are listed as follow, most of which are
optional and has default value as shown in the bracket.

- **IMG_NAME** (`img`), name to be appeared in the file name of AppImage final
  output. It is also used as the name for the local build directory.
- **REPO_URL** (https://github.com/FreeCAD/FreeCAD), the git URL of your
  FreeCAD repo.
- **REPO_BRANCH** (`master`), branch, tag, or commit of the git repo to checkout.
- **REPO_VER** (`1`), set to 1 to include the git checkout hash to the file
  name of AppImage final output.
- **DPKG_URL** (https://git.launchpad.net/~freecad-maintainers/+git/gitpackaging), 
  the git URL of Debian package repo.
- **DPKG_BRANCH** (dailybuild-occt), the git branch of the Debian package repo.
- **AIMG_URL** (https://github.com/realthunder/AppImages.git), the git URL of
  AppImage script repo.
- **AIMG_BRANCH** (`master`), the git branch of the AppImage repo
- **WB_LIST**, space delimited name list of personal workbenches to
  install. The name will also be used for the local installation directory.
- **WB_URL_`<name>`**: the git URL of the workbench named `<name>`
- **WB_BRANCH_`<name>`** (`master`) branch, tag, or commit of the workbench named
  `<name>` to checkout
- **WB_VER_`<name>`** (`1`), set to 1 to include the git checkout hash of the
  workbench named `<name>` to the file name of AppImage final output.
- **WB_PATH_`<name>`** (`Mod`), path relative to FreeCAD installation directory
  to install the workbench named `<name>`
- **WB_SUB_`<name>`**, a list of submodule names to checkout

