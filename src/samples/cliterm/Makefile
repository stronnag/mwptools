VALAC=valac

include ../../common.mk
include ../../valaopts.mk

APP=xcliterm
CLI=cliterm

COMMOND=../../common
CLIB=../../clib

CLIBS= $(CLIB)/btdev.c $(CLIB)/cserial.c

DEVSRC=$(COMMOND)/devman.vala
ifeq ($(XOS),Linux)
DEVSRC += $(COMMOND)/usbmgr.vala $(COMMOND)/bluez.vala $(COMMOND)/bluetooth.vala $(COMMOND)/ble-helper.vala $(COMMOND)/btdevice.vala $(COMMOND)/ble_uuids.vala
endif

COMMONC=$(COMMOND)/serial-device.vala $(COMMOND)/mspcmd.vala $(COMMOND)/mwplog.vala \
	$(COMMOND)/mspmsg.vala $(COMMOND)/sede.vala $(COMMOND)/mwp_uriparser.vala \
	$(COMMOND)/utils.vala $(DEVSRC) $(CLIBS)

PKGS = --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg linux --pkg mwpfuncs
PKGSV = --pkg vte-$(VTEVERS)
PKGSR = --pkg gio-2.0  $(GUDEV)
OPTS+=--vapidir=$(COMMOND) -X -I$(COMMOND)


APPS=$(APP) $(CLI)

all: $(APPS)

cliterm: cliterm.vala $(COMMONC)
	$(VALAC) $(OPTS) $(DOPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

msptest: msptest.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

msptest1: msptest1.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

wp0: wp0.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

mspfuzz: mspfuzz.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

mspcommon: mspcommon.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

mspmixer: mspmixer.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

vxtest: vxtest.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

msp-msg-test: msp-msg-test.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

fsender: fsender.vala $(COMMONC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

rxtest: rxtest.vala $(COMMONC)
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
