#!/bin/sh

dstr=$(date +%F)
txt=$(git log -1 --format="%h" || echo "local")
txt="$txt / $dstr"
echo "char * mwpvers=\"$txt\";" > mwpvers.c
