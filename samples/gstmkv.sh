#!/bin/bash

# This is used to make the videos I've posted to vimeo / you tube for
# flight analysis

OUT=${1:-mwp-example.mkv}

if ! pgrep -x  mwp
then
 setsid mwp --dont-maximise  >/dev/null 2>&1 &
 sleep 2
fi

# Change the screen size to suite your needs / hardware here
# note also prorata values in ffmpeg command line.
# hdmi-stereo.monitor
MON='monitor'

XRES=1280
YRES=720
YYRES=$((YRES + 32))
SX=32
SY=132
wmctrl -F -x -r 'mwp.Mwp' -e 0,$SX,$SY,$XRES,$YRES

F=pulse
S=$(pactl list | grep $MON | grep Name: | cut -d ' ' -f 2)
echo $S

read -p "Hit ENTER to start > "

ENDX=$(($SX+$XRES-1))
ENDY=$(($SY+$YYRES+7))

gst-launch-1.0 -q -e \
  ximagesrc startx=$SX starty=$SY endx=$ENDX endy=$ENDY use-damage=false \
  ! videoconvert \
  ! queue \
  ! vp8enc \
  ! progressreport update-freq=1 \
  ! mux. pulsesrc device=$S \
  ! audio/x-raw \
  ! queue \
  ! audioconvert ! vorbisenc ! mux. matroskamux name=mux \
  ! filesink location=$OUT
