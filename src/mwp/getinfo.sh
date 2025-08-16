#!/usr/bin/env bash

OUTPUT=${1:=_mwpvers.h}

TNOW=$(date -u +%FT%T)
NODE=$(uname -n)
PLAT=$(uname -smr)

CC=${CC:-cc}
LD=${LD-ld}

CVERS=$($CC -v 2>&1 | grep " version " | head -n 1)
VVERS=$(valac --version 2>&1)
LDVERS=$($LD -v 2>&1 | head -n 1)
GITVERS=$(git rev-parse  --short HEAD)
GITBRANCH=$(git branch --show-current)
GITSTAMP=$(git log -1 --format=%cI)
GITTAG=$(git describe --tags --abbrev=0)

> $OUTPUT echo "#define BUILDINFO \"${TNOW}Z ${PLAT} ${NODE}\""
>> $OUTPUT echo "#define COMPINFO \"${CVERS} / ${LDVERS} / ${VVERS}\""
>> $OUTPUT echo "#define MWPGITVERSION \"${GITVERS} (${GITBRANCH})\""
>> $OUTPUT echo "#define MWPGITSTAMP \"${GITSTAMP}\""
