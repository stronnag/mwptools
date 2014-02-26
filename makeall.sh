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

CVERS=$(pkg-config --modversion champlain-0.12)
case $CVERS in
0.12.[0-3]) TGT=mwpu ;;
*) TGT=mwp ;;
esac

for P in mspsim  pidedit switchedit
do
  cd $P
  make $PRECLEAN install-local $POSTCLEAN
  cd ..
done

cd mwp
make $PRECLEAN $TGT install-local $POSTCLEAN
