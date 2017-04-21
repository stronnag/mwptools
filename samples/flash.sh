#!/bin/bash

# if your distro doen't provide it
# stm32flash => git://git.code.sf.net/p/stm32flash/code
# hex2bin    => https://sourceforge.net/projects/hex2bin/?source=typ_redirect
#
# and (most distros do provide this)
# dfu-util => http://sourceforge.net/p/dfu-util
#

DEV=
SPEED=115200
HEX=
RESCUE=
BIN=
RM=
FERASE=
SWITCH=

for P
do
  case $P in
    [123456789]*) SPEED=$P ;;
    /dev/*) DEV=$P ;;
    *.hex) HEX=$P ;;
    *.bin) BIN=$P ;;
    rescue) RESCUE=1 ;;
    switch) SWITCH=1 ;;
    force|erase) FERASE=1 ;;
  esac
done

case $HEX in
  *SPRACINGF3EVO.hex|*OMNIBUS*.hex)
    BIN=${HEX%%hex}bin
    IHEX=$HEX
    unset HEX
    RM=$BIN
    ;;
esac

if [ -z "$DEV" ]
then
 [ -n "$HEX" ] && DEV=/dev/ttyUSB0 || DEV=/dev/ttyACM0
fi

DEV0=$DEV
if [ -n "$SWITCH" ]
then
   [ -e /dev/ttyACM0 ] &&  DEV0=/dev/ttyACM0
fi

echo $DEV0 $RESCUE
if [ -z "$RESCUE" ]
then
  stty -F $DEV0 raw speed $SPEED -crtscts cs8 -parenb -cstopb -ixon
  echo -n 'R' >$DEV0
  sleep 0.2
fi

if [ -n "$HEX" ]
then
  if [ -n "$FERASE" ]
  then
    stm32flash -o -b $SPEED $DEV
  fi
  stm32flash -w $HEX -v -g 0x0 -b $SPEED $DEV
fi

if [ -n "$BIN" ]
then
  objcopy -I ihex $IHEX -O binary $BIN
  sleep 1
  dfu-util -d 0483:df11 --alt 0 -s 0x08000000:mass-erase:force:leave -D $BIN
  [ -n $RM ] && rm -f $RM
fi
