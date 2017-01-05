VALAC=valac

include ../common.mk

LOPTS=-X -lm
APP=mspsim
SRC=$(APP).vala
COMMON=../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspcmd.vala  ../common/mspmsg.vala ../common/get_locale_double.c ../common/mwplog.vala  ../common/btdev.c ../common/cserial.c

PKGS=--pkg posix --pkg linux --pkg gio-2.0 --pkg gtk+-3.0 --pkg libxml-2.0 --pkg json-glib-1.0

$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	install -d $(prefix)/bin
	install -d $(datadir)/share/$(APP)
	install -d $(datadir)/share/applications
	install -s $(APP) $(prefix)/bin/$(APP)
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/$(APP)/mwp_icon.svg
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/$(APP)/$(APP)_icon.svg
	install -m 644 $(APP).ui $(datadir)/share/$(APP)/$(APP).ui
	install -m 644 $(APP).desktop $(datadir)/share/applications/$(APP).desktop
