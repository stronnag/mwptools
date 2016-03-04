#!/usr/bin/env bash

APP=$1
LOC=$2

case $LOC in
local)
    BIN=$HOME/bin
    DATA=$HOME/.local/share
    ;;
*)
    PREFIX=${PREFIX:-/usr}
    BIN=${PREFIX}/bin
    DATA=${PREFIX}/share
    ;;
esac

[ -d $BIN ] || mkdir -p $BIN
[ -d $DATA ] || mkdir -p $DATA
cp $APP $BIN/

[ -d $DATA/$APP ] || mkdir -p $DATA/$APP
[ -e  ${APP}_icon.svg ] && ICON=${APP}_icon.svg || ICON=../common/mwp_icon.svg
[ -e $APP.ui ] && cp $APP.ui $DATA/$APP/
[ -e $ICON ] && cp $ICON $DATA/$APP/
[ -e ../common/mwchooser.ui ] && cp ../common/mwchooser.ui  $DATA/$APP/
[ -d $DATA/icons/hicolor/48x48/apps ] || mkdir -p $DATA/icons/hicolor/48x48/apps
[ -e $ICON ] && cp $ICON $DATA/icons/hicolor/48x48/apps/
[ -d pixmaps ] && cp -a pixmaps $DATA/mwp
[ -f bleet.ogg ] && cp bleet.ogg $DATA/mwp
[ -f bleet.ogg ] && cp bleet.ogg $DATA/mwp
[ -f sat_alert.ogg ] && cp sat_alert.ogg $DATA/mwp

[ -d $DATA/applications ] || mkdir -p $DATA/applications
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

[ "$LOC" = "local" ] && cat <<_EOM
***************************************************************
* For a local install, binaries are in $HOME/bin
* Ensure you have set the following environment variable
* (add to $HOME/.bashrc, or equivalent for your shell)
* export XDG_DATA_DIRS=/usr/share:$HOME/.local/share:
* (or FreeBSD)
* export XDG_DATA_DIRS=/usr/local/share:$HOME/.local/share:
***************************************************************
_EOM
exit 0
