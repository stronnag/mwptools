#!/bin/bash

# if your distro doen't provide it 
# git://git.code.sf.net/p/stm32flash/code

DEV=/dev/ttyUSB0
SPEED=115200
HEX=obj/cleanflight_NAZE.hex
RESCUE=

for P
do
  case $P in
    [123456789]*) SPEED=$P ;;
    /dev/*) DEV=$P ;;
    *.hex) HEX=$P ;;
    rescue) RESCUE=1 ;;
  esac
done

stty -F $DEV raw speed $SPEED -crtscts cs8 -parenb -cstopb -ixon
if [ -z "$RESCUE" ]
then
  echo -n 'R' >$DEV
  sleep 0.2
fi
stm32flash -w $HEX -v -g 0x0 -b $SPEED $DEV
