VALAC=valac

include ../../common.mk

APP=xcliterm
CLI=cliterm

COMMON=../../common/serial-device.vala ../../common/btdev.c \
	../../common/cserial.c ../../common/mspcmd.vala ../../common/mwplog.vala \
	../../common/mspmsg.vala
PKGS = --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg linux
PKGSV = --pkg vte-$(VTEVERS)
PKGSR = --pkg gio-2.0

APPS=$(APP) $(CLI) mspfuzz

all: $(APPS)

cliterm: cliterm.vala $(COMMON)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

msptest: msptest.vala $(COMMON)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

mspfuzz: mspfuzz.vala $(COMMON)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

vxtest: vxtest.vala $(COMMON)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

xcliterm: xcliterm-main.vala ../../common/cliterm.vala $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) $(PKGSV) -o $@  $^ $(LOPTS)

clean:
	rm -f cliterm xcliterm *.vala.c *~ vxtest mspfuzz msptest

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s $(CLI) $(prefix)/bin/$(CLI)
