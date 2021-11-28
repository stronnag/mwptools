#!/bin/sh
## Starting point for Debian & Ubuntu packages ...

CONF=$1
CONFIRM=
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
    libgstreamer-plugins-base1.0-dev \
    libvte-2.91-dev \
    libncurses5-dev \
    golang-go \
    ruby ruby-json \
    libspeechd-dev flite flite1-dev libmosquitto-dev \
    gnuplot ruby-nokogiri unzip

git clone --depth 1 https://github.com/stronnag/mwptools
(
  mkdir -p ~/.local/bin
 cd mwptools
 meson build --buildtype=release --strip --prefix ~/.local
 cd build
 ninja install
)

git clone --depth 1  https://github.com/iNavFlight/blackbox-tools
(
  cd blackbox-tools
  make && make install prefix=~/.local
)

echo
echo "If all went OK, you should have mwp(tools) and blackbox-decode in $HOME/.local/bin"
echo "Please ensure that $HOME/.local/bin is on your PATH"
