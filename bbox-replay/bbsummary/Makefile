
include ../../common.mk

all : BBS

install:
	-install -m 755 target/release/bbsummary  $(prefix)/bin/bbsummary

BBS:
	-cargo build --release

.PHONY: BBS install
