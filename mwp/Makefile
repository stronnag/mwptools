VALAC=valac

APPS=mwp

include ../common.mk

GST ?= 0.10

all: $(APPS)

SRCS=mwp.vala liststore.vala mwp_markers.vala mwp_craft.vala settings.vala dialogs.vala mapsources.vala logger.vala espeak_wrapper.c mwp-replay.vala map_seeder.vala mwp-layout.vala layout-test.vala iparser.vala mwp_bbox.vala

COMMON=../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspmsg.vala ../common/mspcmd.vala  ../common/get_locale_double.c ../common/mwc.vala ../common/mwplog.vala ../common/mavcmd.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg libxml-2.0 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg gdl-3.0 --pkg pango --pkg libsoup-2.4 --pkg linux --pkg gstreamer-$(GST)

LOPTS=-X -lespeak -X -lm

#mwp-gresources.c: mwp-gresources.xml mwp.ui pixmaps/mwp_icon.svg
#	glib-compile-resources --target=$@ --generate-source  mwp-gresources.xml

mwp: $(SRCS) $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

qproxy: qproxy.vala
	valac --pkg libsoup-2.4 --pkg posix  qproxy.vala

clean:
	rm -f mwp qproxy *~ *.vala.c

install: install-local

install-local: $(APPS)
	../installer.sh mwp local
ifdef QPROXY
	../installer.sh qproxy local
endif

install-system: $(APPS)
	../installer.sh mwp system
ifdef QPROXY
	../installer.sh qproxy system
endif
