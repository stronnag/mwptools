VALAC=valac

include ../../common.mk

APP=xcliterm
CLI=cliterm

COMMOND=../../common

COMMONC=$(COMMOND)/serial-device.vala $(COMMOND)/btdev.c \
	$(COMMOND)/cserial.c $(COMMOND)/mspcmd.vala $(COMMOND)/mwplog.vala \
	$(COMMOND)/mspmsg.vala
PKGS = --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg linux --pkg mwpfuncs
PKGSV = --pkg vte-$(VTEVERS)
PKGSR = --pkg gio-2.0
OPTS+=--vapidir=$(COMMOND) -X -I$(COMMOND)


APPS=$(APP) $(CLI) mspfuzz

all: $(APPS)

cliterm: cliterm.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

msptest: msptest.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

mspfuzz: mspfuzz.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

mspcommon: mspcommon.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

vxtest: vxtest.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

xcliterm: xcliterm-main.vala $(COMMOND)/cliterm.vala $(COMMONC)
	$(VALAC) $(OPTS) $(PKGS) $(PKGSV) -o $@  $^ $(LOPTS)

clean:
	rm -f cliterm xcliterm *.vala.c *~ vxtest mspfuzz msptest

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s $(CLI) $(prefix)/bin/$(CLI)
