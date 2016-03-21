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
wmctrl -F -x -r 'mwp.Mwp' -e 0,32,32,$XRES,$YRES

F=pulse
S=$(pactl list | grep monitor | grep Name: | cut -d ' ' -f 2)
#S=default

read -p "Hit ENTER to start > "

# note older versions of Ubuntu / Debian may need avconv rather than ffmpeg
# FFMPEG=avconv
#
FFMPEG=ffmpeg
$FFMPEG -y -f $F  -thread_queue_size 512 -i $S -thread_queue_size 512 \
	-f x11grab -framerate 15 -ac 1 -s ${XRES}x${YYRES} \
	-acodec pcm_s16le \
	-i ${DISPLAY}+32,32 -vcodec libx264  -preset ultrafast \
	-tune zerolatency  $OUT
