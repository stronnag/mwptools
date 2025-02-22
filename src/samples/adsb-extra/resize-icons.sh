#!/usr/bin/env bash

if ! type -t > /dev/null identify ; then
  echo "This script requires "identify" (typically from imagemagick package)"
  exit 127
fi
if ! type -t > /dev/null rsvg-convert ; then
  echo "This script requires "rsvg-convert" (typically from librsvg package)"
  exit 127
fi
if ! type -t > /dev/null dc ; then
  echo "This script requires "dc" (typically from bc or dc package)"
  exit 127
fi

usage() {
  echo "resize-icons.sh -f factor files..."
  exit 127
}

FACTOR=
while getopts "f:h" FOO
do
  case $FOO in
    f) FACTOR=$OPTARG ;;
    *) usage ;;
  esac
done

[ -z "$FACTOR" ]  && { echo "Need a scale factor"; usage; }

shift $((OPTIND -1))
NEED=$*
for F in $NEED
do
  if [ -e $F ] ; then
    R=$(identify -format "%m %d %f %w %h\n" $F)
    readarray -d ' ' -t arr <<<"$R"
    if [ "${arr[0]}" == "SVG" ] ; then
      W=${arr[3]}
      H=${arr[4]}
      W1=$(dc -e "2 k $W  $FACTOR * p")
      H1=$(dc -e "2 k $H  $FACTOR * p")
      OF="${arr[1]}/_${arr[2]}"
      mv $F $OF
      echo "rsvg-convert -w $W1 -h $H1 -a -f svg -o $F $OF"
      rsvg-convert -w $W1 -h $H1 -a -f svg -o $F $OF
    fi
  fi
done
echo "For ADSB symbols, you may have to (re)apply  'id=\"mwpfg\"' and 'id=\"mwpbg\"' attributes to the resized icons : see gradient/README.md"
echo "For other symbols, you may have to (re)apply 'mwp:xalign' or 'mwp:yalign' attributes to the resized icons"
