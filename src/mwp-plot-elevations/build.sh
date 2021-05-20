#!/usr/bin/env bash
OUTPUT=${1:-mwp-plot-elevations}
cd $(dirname $0)
go build -trimpath -ldflags "-w -s" -o $OUTPUT
