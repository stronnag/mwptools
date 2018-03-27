VALAC=valac

include ../common.mk

CLI=fc-get
CLIS=fc-set

COMMOND=../common

COMMONC=$(COMMOND)/serial-device.vala $(COMMOND)/btdev.c \
	$(COMMOND)/cserial.c $(COMMOND)/mspcmd.vala $(COMMOND)/mwplog.vala \
	$(COMMOND)/mspmsg.vala $(COMMOND)/devman.vala  $(COMMOND)/mwptermcap.vala
PKGS = --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg linux --pkg mwpfuncs
PKGSV = --pkg vte-$(VTEVERS)
PKGSR = --pkg gio-2.0 $(GUDEV)

OPTS+=--vapidir=$(COMMOND) -X -I$(COMMOND)
LOPTS+=-X -lncurses

all: $(CLI)

fc-get: fc-get.vala $(COMMONC)
	$(VALAC) $(DOPTS) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)
	ln -f fc-get fc-set

clean:
	rm -f fc-get fc-set *.vala.c *~

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(CLI) $(prefix)/bin/$(CLI)
	ln -f $(prefix)/bin/$(CLI) $(prefix)/bin/$(CLIS)
