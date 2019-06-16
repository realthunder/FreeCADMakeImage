#!/bin/bash

set -e

deps=$1
test "$deps" || deps=./bionic_deps.sh

uid=$2
test "$uid" || uid=1000

source $deps

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

useradd -u $uid -ms /bin/bash freecad
echo 'freecad:freecad' |chpasswd

