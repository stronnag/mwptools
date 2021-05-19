#!/usr/bin/env bash

OUTPUT=${1:-otxlog}
cd $(dirname $0)
go build -trimpath -ldflags "-w -s" -o $OUTPUT
