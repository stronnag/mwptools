#!/bin/bash

# if your distro doen't provide it
# stm32flash => git://git.code.sf.net/p/stm32flash/code
#
# and (most distros do provide this)
# dfu-util => http://sourceforge.net/p/dfu-util
#
# This file is part of https://github.com/stronnag/mwptools
#   mission planning, logging replay and utilities for iNav / multiwii 2.4+

#####################################################################
# Note 'rescue' may require explicit device name
#####################################################################

function find_serial
{
  local USB
  local SDEV

  if type lsusb 2>&1 >/dev/null ; then
    USB=$(lsusb -d  0483:)
    [[ "$USB" =~ "STM" ]] && BASE="ACM"
  else
     [ -e /dev/ttyACM0 ] && BASE=ACM || BASE=USB
  fi

 [ -z "$BASE" ] && BASE=USB

  SDEV=
  for (( i=0; i<10; i++))
  do
    d="/dev/tty${BASE}${i}"
    if [ -e "$d" ] ; then
      SDEV=$d
      break
    fi
  done
  echo $SDEV
}

DEV=
SPEED=115200
HEX=
RESCUE=
BIN=
RM=
FERASE=1
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
    noerase) FERASE= ;;
  esac
done


[ -f $HEX ] || { echo "$HEX not found" ; exit ; }

[ -z "$DEV" ] && DEV=$(find_serial)

if [[ "$DEV" =~ "/dev/ttyACM" ]] ; then
    BIN=${HEX%%hex}bin
    IHEX=$HEX
    unset HEX
    RM=$BIN
fi

DEV0=$DEV
if [ -n "$SWITCH" ]
then
   [ -e /dev/ttyACM0 ] &&  DEV0=/dev/ttyACM0
fi

echo $DEV0 $RESCUE
if [ -z "$RESCUE" ]
then
  stty -F $DEV0 raw speed $SPEED -crtscts cs8 -parenb -cstopb -ixon || { echo "stty failed to set speed, doomed" ; exit 1 ; }
  echo -n 'R' >$DEV0
  sleep 0.2
  if [ $SPEED -ne 115200 ]
  then
    SPEED=115200
    stty -F $DEV0 raw speed $SPEED -crtscts cs8 -parenb -cstopb -ixon
  fi
fi

if [ -n "$HEX" ]
then
  if [ -n "$FERASE" ]
  then
    echo STM32FLASH: stm32flash -o -b $SPEED $DEV
    stm32flash -o -b $SPEED $DEV
  fi
  echo STM32FLASH: stm32flash -w $HEX -v -e 0 -g 0x0 -b $SPEED $DEV
  stm32flash -w $HEX -v -g 0x0 -b $SPEED $DEV
fi

if [ -n "$BIN" ]
then
  objcopy -I ihex $IHEX -O binary $BIN
  sleep 1
  ERASE=
  [ -n "$FERASE" ] && ERASE="mass-erase:"
  echo DFU: dfu-util -d 0483:df11 --alt 0 -s 0x08000000:${ERASE}force:leave -D $BIN
  dfu-util -d 0483:df11 --alt 0 -s 0x08000000:${ERASE}force:leave -D $BIN
  [ -n $RM ] && rm -f $RM
fi
