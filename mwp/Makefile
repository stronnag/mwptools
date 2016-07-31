VALAC=valac

APPS=mwp

include ../common.mk

GST ?= 0.10

all: $(APPS)

SRCS=mwp.vala liststore.vala mwp_markers.vala mwp_craft.vala settings.vala dialogs.vala mapsources.vala logger.vala espeak_wrapper.c mwp-replay.vala map_seeder.vala mwp-layout.vala layout-test.vala iparser.vala mwp_bbox.vala mwpvers.c

COMMON=../common/btdev.c ../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspmsg.vala ../common/mspcmd.vala  ../common/get_locale_double.c ../common/mwc.vala ../common/mwplog.vala ../common/mavcmd.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg libxml-2.0 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg gdl-3.0 --pkg pango --pkg libsoup-2.4 --pkg linux --pkg gstreamer-$(GST)

LOPTS=-X -lespeak -X -lm

#mwp-gresources.c: mwp-gresources.xml mwp.ui pixmaps/mwp_icon.svg
#	glib-compile-resources --target=$@ --generate-source  mwp-gresources.xml

.PHONY: mwpvers.c

mwpvers.c:
	./mkvers.sh

mwp: $(SRCS) $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f mwp *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D mwp $(prefix)/bin/mwp
	install -m 644 -D ../common/mwp_icon.svg $(datadir)/share/mwp/mwp_icon.svg
	install -m 644 -D ../common/mwp_icon.svg $(datadir)/share/icons/hicolor/scalable/mwp_icon.svg
	install -m 644 -D ../common/mwp_icon.svg $(datadir)/share/mwp/mwp.svg
	install -m 644 -D ../common/mwp_icon.svg $(datadir)/share/mwp/pixmaps/mwp_icon.svg
	install -m 644 -D mwp.ui $(datadir)/share/mwp/mwp.ui
	install -d $(datadir)/share/mwp/pixmaps
	install -m 644 pixmaps/* $(datadir)/share/mwp/pixmaps/
	install -m 644 *.ogg $(datadir)/share/mwp/
	install -m 644 -D mwp.desktop $(datadir)/share/applications/mwp.desktop
	install -m 644 -D org.mwptools.planner.gschema.xml $(datadir)/share/glib-2.0/schemas/org.mwptools.planner.gschema.xml
	glib-compile-schemas $(datadir)/share/glib-2.0/schemas
	install -m 644 -D ../docs/mwptools.pdf $(datadir)/share/doc/mwp/mwptools.pdf
