#!/bin/bash


CVERS=$(pkg-config --modversion champlain-0.12)

case $CVERS in
0.12.[0-3]) TGT=mwpu ;;
*) TGT=mwp ;;
esac

for P in mspsim  pidedit
do
  cd $P
  make clean install-local
  make clean
  cd ..
done

cd mwp
make clean $TGT install-local
make clean
