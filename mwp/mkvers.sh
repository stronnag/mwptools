#!/bin/sh

dstr=$(date +%F)
txt=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
txt="$txt / $dstr"
if [ -f .master ] ; then
 y=$(($(date +%y)-17))
 mwpid=$y.$(date +%j).$(($(date +%s)%86400/100))
 echo "char * mwpid=\"$mwpid\";" > mwpid.h
fi

echo "char *mwpvers=\"$txt\";" > mwpvers.h
cat "mwpid.h" >> mwpvers.h
