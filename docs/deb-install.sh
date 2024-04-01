#!/usr/bin/env bash

## Starting point for Debian & Ubuntu packages ...
function usage
{
  echo "deb-install.sh [-y] [-d]"
  echo " Install debian / Ubuntu dependendcies [and build mwp]"
  echo " -y    No confirmation"
  echo " -d    Dependencies only"
  exit
}

CONFIRM=
DEPSONLY=

while getopts "ydh" FOO
do
 case $FOO in
   y) CONFIRM=-y ;;
   d) DEPSONLY=1 ;;
   *) usage ;;
 esac
done

[ "$#" -eq 0 ] && usage
shift $((OPTIND -1))
CONF=$1
[ -n "$CONF" ] && CONFIRM=-y

sudo apt update && sudo apt full-upgrade && \
  sudo apt $CONFIRM install libgdl-3-dev \
    libchamplain-gtk-0.12-dev \
    libchamplain-0.12-dev \
    libclutter-1.0-dev \
    libclutter-gtk-1.0-dev \
    libgtk-3-dev \
    valac \
    pkg-config \
    git build-essential \
    meson \
    ninja-build \
    libbluetooth-dev \
    libespeak-dev \
    libgudev-1.0-dev \
    libgstreamer1.0-dev \
    gstreamer1.0-plugins-good \
    libgstreamer-plugins-base1.0-dev \
    libvte-2.91-dev \
    libncurses5-dev \
    golang-go \
    ruby ruby-json \
    desktop-file-utils \
    libspeechd-dev flite flite1-dev libmosquitto-dev \
    gnuplot ruby-nokogiri unzip


[ -n "$DEPSONLY" ] && exit

git clone --depth 1 https://github.com/stronnag/mwptools
(
  mkdir -p ~/.local/bin
  cd mwptools
  meson build --buildtype=release --strip --prefix ~/.local
  cd build
  ninja install
)

echo
echo "If all went OK, you should have mwp(tools) in $HOME/.local/bin"
echo "Please ensure that $HOME/.local/bin is on your PATH"
echo "Don't forget to install replay tools, see https://stronnag.github.io/mwptools/replay-tools/"
