#!/bin/bash

gcc -o ath $(pkg-config --cflags gtk+-2.0) ath.c gtkartificialhorizon.c \
    $(pkg-config --libs gtk+-2.0)

mv ath ~/bin/mwp_ath
valac --pkg gtk+-3.0 --pkg posix    atest.vala -X -lm
