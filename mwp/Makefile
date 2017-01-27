VALAC=valac

APPS=mwp

include ../common.mk

GST ?= 1.0

all: $(APPS)

SRCS=mwp.vala liststore.vala mwp_markers.vala mwp_craft.vala settings.vala dialogs.vala mapsources.vala logger.vala espeak_wrapper.c mwp-replay.vala map_seeder.vala mwp-layout.vala layout-test.vala iparser.vala mwp_bbox.vala ah_widget.vala _mwpvers.c

COMMON=../common/btdev.c ../common/cserial.c ../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspmsg.vala ../common/mspcmd.vala  ../common/get_locale_double.c ../common/mwc.vala ../common/mwplog.vala ../common/mavcmd.vala local_geo.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg libxml-2.0 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg gdl-3.0 --pkg pango --pkg cairo --pkg libsoup-2.4 --pkg linux --pkg gstreamer-$(GST)

LOPTS=-X -lespeak -X -lm

#mwp-gresources.c: mwp-gresources.xml mwp.ui pixmaps/mwp_icon.svg
#	glib-compile-resources --target=$@ --generate-source  mwp-gresources.xml

mwp: $(SRCS) $(COMMON)
	./mkvers.sh
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f mwp *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s mwp $(prefix)/bin/mwp
	install -d $(datadir)/share/mwp
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/mwp/mwp_icon.svg
	install -d $(datadir)/share/icons/hicolor/scalable
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/icons/hicolor/scalable/mwp_icon.svg
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/mwp/mwp.svg
	install -d $(datadir)/share/pixmaps
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/pixmaps/
	install -d $(datadir)/share/mwp/pixmaps
	install -m 644 ../common/mwp_icon.svg $(datadir)/share/mwp/pixmaps/mwp_icon.svg
	install -m 644 mwp.ui $(datadir)/share/mwp/mwp.ui
	install -m 644 pixmaps/* $(datadir)/share/mwp/pixmaps/
	install -m 644 *.ogg $(datadir)/share/mwp/
	install -d $(datadir)/share/applications
	install -m 644 mwp.desktop $(datadir)/share/applications/mwp.desktop
	install -d $(datadir)/share/glib-2.0/schemas
	install -m 644 org.mwptools.planner.gschema.xml $(datadir)/share/glib-2.0/schemas/org.mwptools.planner.gschema.xml
	glib-compile-schemas $(datadir)/share/glib-2.0/schemas
	install -d $(datadir)/share/doc/mwp
	install -m 644 ../docs/mwptools.pdf $(datadir)/share/doc/mwp/mwptools.pdf
