#!/usr/bin/env bash

OUTPUT=$1
cd $2
TRIMP=$3
go build $TRIMP  -ldflags "-w -s" -o $OUTPUT
