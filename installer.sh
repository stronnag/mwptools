#!/bin/bash

APP=$1
LOC=$2

case $LOC in
local)
    BIN=$HOME/bin
    DATA=$HOME/.local/share
    ;;
system)
    BIN=/usr/bin
    DATA=/usr/share
    ;;
esac

[ -d $BIN ] || mkdir -p $BIN
[ -d $DATA ] || mkdir -p $DATA
cp $APP $BIN/
[ -d $DATA/$APP ] || mkdir -p $DATA/$APP
[ -e $APP.ui ] && cp $APP.ui ../common/mwp_icon.svg $DATA/$APP/
[ -d $DATA/icons/hicolor/48x48/apps ] || mkdir -p $DATA/icons/hicolor/48x48/apps
cp ../common/mwp_icon.svg $DATA/icons/hicolor/48x48/apps/
[ -d pixmaps ] && cp -a pixmaps $DATA/mwp

[ -e $APP.desktop ] && cp $APP.desktop  $DATA/applications/

COMP=
F=$(find . -iname \*gschema.xml)
if [ -n "$F" -a -e "$F" ]
then
  [ -d $DATA/glib-2.0/schemas ] || mkdir -p $DATA/glib-2.0/schemas
  cp $F  $DATA/glib-2.0/schemas/
  COMP=Y
fi
[ -n "$COMP" ] && glib-compile-schemas $DATA/glib-2.0/schemas/

exit 0
