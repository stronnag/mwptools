CFLAGS=-O2 `pkg-config --cflags gtk+-2.0`
LDFLAGS=`pkg-config --libs gtk+-2.0`

include ../common.mk

APP=mwp_ath

mwp_ath: ath.c gtkartificialhorizon.c  gtkartificialhorizon.h
	$(CC) $(CFLAGS) ath.c gtkartificialhorizon.c -o mwp_ath $(LDFLAGS)

atest: atest.vala
	valac --pkg gtk+-3.0 --pkg posix atest.vala -X -lm

clean:
	rm -f mwp_ath atest

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	install -s -D $(APP) $(prefix)/bin/$(APP)
