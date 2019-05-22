include ../common.mk

APPS=mwp-dbus-loc
VALAC=valac

mwp-dbus-loc: mwp-dbus-loc.vala
	$(VALAC) $(OPTS) --pkg gio-2.0  $<

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install ${APPS} $(prefix)/bin/$(APPS)

.PHONY: clean
