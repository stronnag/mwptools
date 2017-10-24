#!/bin/sh

dstr=$(date +%F)
txt=$(git log -1 --format="%h" 2>/dev/null || echo "local")
if [ "$txt" == "local" ]
then
  # From the master source tree
  y=$(($(date +%y)-17))
  mwpid=$y.$(date +%j).$(($(date +%s)%86400/100))
   echo "char * mwpid=\"$mwpid\";" > mwpid.h
fi
txt="$txt / $dstr"
echo "char *mwpvers=\"$txt\";" > mwpvers.h
echo "#include \"mwpid.h\"" >> mwpvers.h
