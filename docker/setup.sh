#!/bin/bash

set -e

arg=$1
test "$arg" || arg="./bionic_deps.sh"
source $arg

export DEBIAN_FRONTEND=noninteractive
export TERM=xterm
export TZ=UTC

apt update 
apt install -y --no-install-recommends software-properties-common
add-apt-repository -y ppa:freecad-maintainers/freecad-daily
apt update
apt install -y --no-install-recommends $build_deps
apt-get clean
rm -rf /var/lib/apt/lists/* \
   /usr/share/doc/* \
   /usr/share/locale/* \
   /usr/share/man/* \
   /usr/share/info/*

useradd -ms /bin/bash freecad
echo 'freecad:freecad' |chpasswd

