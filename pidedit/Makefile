VALAC=valac

include ../common.mk

LOPTS=
APP=pidedit
SRC=$(APP).vala
COMMON=../common/serial-device.vala ../common/utils.vala ../common/mspcmd.vala ../common/mspmsg.vala ../common/mwplog.vala ../common/btdev.c
PKGS= --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg posix --pkg  json-glib-1.0 --pkg linux


$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) *.vala.c

install: $(APP)
	install -d $(prefix)/bin
	install -d $(datadir)/share/$(APP)
	install -d $(datadir)/share/applications
	install -s $(APP) $(prefix)/bin/$(APP)
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/$(APP)/mwp_icon.svg
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/$(APP)/$(APP).svg
	install -m 644 $(APP).ui $(datadir)/share/$(APP)/$(APP).ui
	install -m 644 $(APP).desktop $(datadir)/share/applications/$(APP).desktop
