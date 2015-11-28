#!/bin/bash

# This is used to make the videos I've posted to vimeo / you tube for
# flight analysis

OUT=${1:-mwp-example.mkv}

if ! pgrep  mwp
then
 mwp --dont-maximise  >/dev/null 2>&1 &
 sleep 2
fi

wmctrl -F -r 'mwp' -e 0,32,32,1280,720

F=pulse
S=$(pactl list | grep monitor | grep Name: | cut -d ' ' -f 2)

read -p "Hit ENTER to start > "

ffmpeg -y -f $F -i $S -f x11grab -acodec pcm_s16le -r 30 -s 1280x756 \
 -i ${DISPLAY}+32,32 -vcodec libx264 -crf 0 -preset ultrafast -threads 0 $OUT
