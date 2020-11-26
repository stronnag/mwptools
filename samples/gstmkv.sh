#!/bin/bash

# This is used to make the videos I've posted to vimeo / you tube for
# flight

OUT=${1:-mwp-example.mkv}

if ! pgrep -x  mwp
then
 mwp --dont-maximise  >/dev/null 2>&1 &
 sleep 2
fi

# Change the screen size to suite your needs / hardware here
# note also prorata values in ffmpeg command line.
XRES=1400
YRES=900

SX=32
SY=132
wmctrl -F -x -r 'mwp.Mwp' -e 0,$SX,$SY,$XRES,$YRES

sx=$SX
sy=$SY
xs=$XRES
ys=$YRES
xl=$((sx+xs-1))
yl=$((sy+ys-1))

#while read -r -a arr
#do
#  if [ "${arr[7]}" = "mwp" ] ; then
#    sx=${arr[2]}
#    sy=${arr[3]}
#    xs=${arr[4]}
#    ys=${arr[5]}
#    xl=$(($sx+$xs-1))
#    yl=$(($sy+$ys-1))
#  fi
#done < <(wmctrl -G -l)

F=pulse
#S=$(pactl list | grep monitor | grep Name: | cut -d ' ' -f 2)
S=default
while read -r S
do
  echo $S; break
done < <(pactl list | grep monitor | grep Name: | cut -d ' ' -f 2)


# note older versions of Ubuntu / Debian may need avconv rather than ffmpeg
# FFMPEG=avconv
#
#FFMPEG=ffmpeg
#$FFMPEG -y -f $F  -thread_queue_size 512 -i $S -thread_queue_size 512 \
#	-f x11grab -framerate 15 -ac 1 -s ${XRES}x${YRES} \
#	-acodec pcm_s16le \
#	-i ${DISPLAY}+$SX,$SY -vcodec libx264  -preset ultrafast \
#	-tune zerolatency $OUT

CMD="gst-launch-1.0 -e \
  ximagesrc display-name=:0 use-damage=false show-pointer=true \
  startx=$sx starty=$sy endx=$xl endy=$yl \
  ! video/x-raw, framerate=25/1 \
  ! videoconvert ! videorate \
  ! queue max-size-bytes=1073741824 max-size-time=10000000000 max-size-buffers=1000 \
  ! videoscale ! video/x-raw, width=$XRES, height=$YRES \
  ! x264enc qp-min=17 qp-max=17 speed-preset=superfast threads=6 \
  ! video/x-h264, profile=baseline ! queue \
  ! mux. pulsesrc device=$S \
  ! audio/x-raw, channels=2 \
  ! queue ! mix. pulsesrc device=$S \
  ! audio/x-raw, channels=2 \
  ! queue ! mix. audiomixer name=mix \
  ! audioconvert ! audiorate ! queue ! vorbisenc ! queue \
  ! mux. matroskamux name=mux writing-app=mwptools-mkmkv \
  ! filesink location=$OUT"

echo $CMD
read -p "Hit ENTER to start > "
$CMD
