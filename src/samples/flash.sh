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

DEPFAIL=
for DEP in lsusb dfu-util stm32flash objcopy
do
  if ! type $DEP 2>&1 >/dev/null ; then
    echo "Missing $DEP"
    DEPFAIL=1
  fi
done

[ -n "$DEPFAIL" ] && exit 127

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
    /dev/*) DEV=$P ;;
    *.hex) HEX=$P ;;
    *.bin) BIN=$P ;;
    rescue) RESCUE=1 ;;
    switch) SWITCH=1 ;;
    erase) FERASE=1 ;;
    noerase) FERASE= ;;
    [123456789]*) SPEED=$P ;;
  esac
done

[ -n "$HEX" ] || { echo "No hexfile provided" ; exit ; }
[ -f $HEX ] || { echo "$HEX not found" ; exit ; }

if [ -n "$RESCUE" ] ; then
  echo "Checking DFU for rescue"
  if dfu-util -l -d 0483:df11 | grep -q "Found DFU" ; then
    [ -z "$DEV" ] && DEV=/dev/ttyACMx # to force BIN mode
  fi
fi

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

if [ -z "$RESCUE" ]
then
  stty -F $DEV0 raw speed $SPEED -crtscts cs8 -parenb -cstopb -ixon || { echo "stty failed to set speed, doomed" ; exit 1 ; }
  echo -n 'R' >$DEV0
  sleep 2
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
