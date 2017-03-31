VALAC=valac

include ../../common.mk

OPTS=-X -Os -X -s
APP=cliterm
SRC=$(APP).vala
COMMON=../../common/serial-device.vala ../../common/btdev.c \
	../../common/cserial.c ../../common/mspcmd.vala ../../common/mwplog.vala \
	../../common/mspmsg.vala ../../common/cliterm.vala
PKGS= --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg linux --pkg vte-$(VTEVERS)


$(APP): cliterm-main.vala $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) *.vala.c
