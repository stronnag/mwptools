#!/bin/bash

# This is used to make the videos I've posted to vimeo / you tube for
# flight analysis

OUT=${1:-mwp-example.mkv}

if ! pgrep -x  mwp
then
 mwp --dont-maximise  >/dev/null 2>&1 &
 sleep 2
fi

# Change the screen size to suite your needs / hardware here
# note also prorata values in ffmpeg command line.
XRES=1280
YRES=720
YYRES=$((YRES + 36))
SX=32
SY=132
wmctrl -F -x -r 'mwp.Mwp' -e 0,$SX,$SY,$XRES,$YRES

F=pulse
S=$(pactl list | grep monitor | grep Name: | cut -d ' ' -f 2)

read -p "Hit ENTER to start > "

ENDX=$(($SX+$XRES-1))
ENDY=$(($SY+$YYRES+7))

gst-launch-1.0 -q -e \
  ximagesrc startx=$SX starty=$SY endx=$ENDX endy=$ENDY \
  ! queue \
  ! videoconvert \
  ! vp8enc \
  ! progressreport update-freq=1 \
  ! mux. pulsesrc device=$S \
  ! audio/x-raw,format=S16LE \
  ! queue \
  ! audioconvert ! vorbisenc quality=0.2 ! mux. \
  matroskamux name=mux \
  ! filesink location=$OUT
