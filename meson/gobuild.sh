#!/usr/bin/env bash
env > /tmp/e.txt

OUTPUT=$1
cd $2
TRIMP=$3
BROOT=$4
go build $TRIMP -ldflags '-w -s'
#if [ -e $OUTPUT ] ; then
#  cp $OUTPUT $BROOT/
#elif [ -e $OUTPUT.exe] ; then
#  cp $OUTPUT.exe $BROOT/
#fi
