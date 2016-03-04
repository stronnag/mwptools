VALAC=valac
LOPTS=
include ../common.mk

APP=switchedit
SRC=$(APP).vala
COMMON=../common/mwc.vala ../common/serial-device.vala ../common/utils.vala ../common/mspcmd.vala ../common/mspmsg.vala ../common/mwplog.vala
PKGS= --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg posix --pkg json-glib-1.0 --pkg linux


$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP)  *.vala.c


local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
	install -m 644 -D ../common/mwp_icon.svg $(datadir)/share/$(APP)/mwp_icon.svg
	install -m 644 -D ../common/mwp_icon.svg $(datadir)/share/$(APP)/$(APP).svg
	install -m 644 -D $(APP).ui $(datadir)/share/$(APP)/$(APP).ui
	install -m 644 -D $(APP).desktop $(datadir)/share/applications/$(APP).desktop
