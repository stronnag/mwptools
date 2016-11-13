#!/bin/bash

# if your distro doen't provide it
# stm32flash => git://git.code.sf.net/p/stm32flash/code
# hex2bin    => https://sourceforge.net/projects/hex2bin/?source=typ_redirect

DEV=
SPEED=115200
HEX=
RESCUE=
BIN=
RM=

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

case $HEX in
  *SPRACINGF3EVO.hex|*AIRBOTF4.hex)
    hex2bin $HEX
    BIN=${HEX%%hex}bin
    unset HEX
    RM=$BIN
    ;;
esac

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
 dfu-util -d 0483:df11  --alt 0 -s 0x08000000:mass-erase:force:leave -D $BIN
 [ -n $RM ] && rm -f $RM
fi
