VALAC=valac

include ../../common.mk

CLI=flashdl

COMMON=../../common/serial-device.vala ../../common/btdev.c \
	../../common/cserial.c ../../common/mspcmd.vala ../../common/mwplog.vala \
	../../common/mspmsg.vala
PKGS = --pkg posix --pkg gio-2.0 --pkg linux
PKGSV = --pkg vte-$(VTEVERS)
PKGSR = --pkg gio-2.0

APPS=$(CLI)

all: $(APPS)

flashdl: flashdl.vala $(COMMON)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

clean:
	rm -f flashdl *.vala.c *~

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s $(CLI) $(prefix)/bin/$(CLI)
