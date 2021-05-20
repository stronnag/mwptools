#!/bin/bash

# This is used to make the videos I've posted to vimeo / you tube for
# flight analysis

OUT=${1:-mwp-cast.mkv}

if ! pgrep -x  mwp
then
 mwp --dont-maximise  >/dev/null 2>&1 &
 disown
 sleep 2
fi

# Change the screen size to suite your needs / hardware here
# note also prorata values in ffmpeg command line.
XRES=1280
YRES=720
YYRES=$((YRES + 36))
wmctrl -F -x -r 'mwp.Mwp' -e 0,32,32,$XRES,$YRES

F=pulse
S=$(pactl list | grep monitor | grep Name: | cut -d ' ' -f 2)
#S=default

read -p "Hit ENTER to start > "

ENDX=$((32+$XRES-1))
ENDY=$((32+$YYRES+7))

gst-launch-0.10 ximagesrc startx=32 starty=32  endx=$ENDX endy=$ENDY ! ffmpegcolorspace ! queue ! vp8enc quality=10 speed=4 threads=4 ! mux. alsasrc ! audio/x-raw-int ! queue ! audioconvert ! vorbisenc quality=0.2 ! mux. matroskamux ! filesink location=$OUT
