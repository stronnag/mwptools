#!/bin/bash

PRECLEAN=
POSTCLEAN=

for ARG
do
  case $ARG in
    pre*) PRECLEAN=clean ;;
    post*) POSTCLEAN=clean ;;
  esac
done

BBOPTS=
SUOPTS=

# This is mainly to support old (LTS) Ubuntu ... alas
pkg-config --atleast-version=2.48 libsoup-2.4 || export SPOPTS="-D BADSOUP"
pkg-config --atleast-version=0.12.3 champlain-0.12 || export BBOPTS="-D NOBB"
pkg-config --atleast-version=2.46 glib-2.0 || export PFOPTS="-D NOPUSHFRONT"
# and again, Ubuntu ....
pkg-config --atleast-version=0.30 libvala-0.30 || export PFOPTS="-D NOPUSHFRONT"

for P in mspsim  pidedit switchedit common cf-cli horizon
do
  echo Building in $P
  cd $P
  make $PRECLEAN install-local $POSTCLEAN
  cd ..
done

cd mwp
make $PRECLEAN mwp install-local $POSTCLEAN
if [ -n "$SPOPTS" ]
then
  make $PRECLEAN qproxy $POSTCLEAN
  ../installer.sh qproxy local
fi
