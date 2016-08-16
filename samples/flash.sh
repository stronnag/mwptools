#!/bin/bash

# if your distro doen't provide it
# git://git.code.sf.net/p/stm32flash/code

DEV=
SPEED=115200
HEX=
RESCUE=
BIN=

for P
do
  case $P in
    [123456789]*) SPEED=$P ;;
    /dev/*) DEV=$P ;;
    *.hex) HEX=$P ;;
    *.bin) BIN=$P ;;    
    rescue) RESCUE=1 ;;
  esac
done

if [ -z "$DEV" ]
then
 [ -n "$HEX" ] && DEV=/dev/ttyUSB0 || DEV=/dev/ttyACM0
fi

echo $DEV

stty -F $DEV raw speed $SPEED -crtscts cs8 -parenb -cstopb -ixon
if [ -z "$RESCUE" ]
then
  echo -n 'R' >$DEV
  sleep 0.5
fi

if [ -n "$HEX" ]
then
 stm32flash -w $HEX -v -g 0x0 -b $SPEED $DEV
fi


if [ -n "$BIN" ]
then
 dfu-util -d 0483:df11  --alt 0 -s 0x08000000:leave -D $BIN
fi
