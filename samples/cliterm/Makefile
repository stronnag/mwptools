VALAC=valac

include ../../common.mk

OPTS=-X -Os -X -s

SRC=$(APP).vala
COMMON=../../common/serial-device.vala ../../common/btdev.c \
	../../common/cserial.c ../../common/mspcmd.vala ../../common/mwplog.vala \
	../../common/mspmsg.vala
PKGS= --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg linux --pkg vte-$(VTEVERS)
PKGSR= --pkg gio-2.0

all: cliterm xcliterm

cliterm: cliterm.vala $(COMMON)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

xcliterm: xcliterm-main.vala ../../common/cliterm.vala $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) cliterm xcliterm *.vala.c *~
