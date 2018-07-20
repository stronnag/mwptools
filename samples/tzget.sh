#!/bin/bash

cd ~/Projects/ZoneDetect-master

ZONE=
while read K V
do
  case $K in
    TimezoneIdPrefix:) ZONE=$V ;;
    TimezoneId:) ZONE=${ZONE}${V} ;;
  esac
done < <(LD_LIBRARY_PATH=$LD_LIBRARY_PATH:./library ./zdemo database/timezone21.bin $1 $2)
echo $ZONE
