VALAC=valac

APPS=mwp

-include ../local.mk
-include local.mk
include ../common.mk

GST ?= 1.0

SPK=
ES1 := $(shell espeak --version > /dev/null; echo $$?)
ifeq ($(ES1),0)
 SPK += -X -DUSE_ESPEAK
endif

ES2 := $(shell pkg-config --exists speech-dispatcher; echo $$?)
ifeq ($(ES2),0)
 SPK += -X -DUSE_SPEECHD
endif

ifdef SPK
  OPTS += --pkg gmodule-2.0
endif

OPTS+= --vapidir $(COMMOND) -X -I$(COMMOND) --pkg mwpfuncs

BASH_COMPLETION_DIR := $(shell pkg-config --variable=completionsdir bash-completion | sed 's/^\/usr\///')

all: $(APPS)

COMMOND=../common

SRCS=mwp.vala liststore.vala mwp_markers.vala mwp_craft.vala settings.vala dialogs.vala mapsources.vala logger.vala speech_wrapper.c mwp-replay.vala map_seeder.vala mwp-layout.vala iparser.vala mwp_bbox.vala ah_widget.vala _mwpvers.c get_places.vala mission.vala mwp_dbus.vala name_type_map.vala

COMMON=$(COMMOND)/btdev.c $(COMMOND)/cserial.c $(COMMOND)/xmlio.vala $(COMMOND)/serial-device.vala $(COMMOND)/geocalc.vala  $(COMMOND)/utils.vala $(COMMOND)/mspmsg.vala $(COMMOND)/mspcmd.vala  $(COMMOND)/mwc.vala $(COMMOND)/mwplog.vala $(COMMOND)/mavcmd.vala local_geo.vala $(COMMOND)/cliterm.vala $(COMMOND)/mlock.vala $(COMMOND)/json_io.vala $(COMMOND)/devman.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg libxml-2.0 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg gdl-3.0 --pkg pango --pkg cairo --pkg libsoup-2.4 --pkg linux --pkg gstreamer-$(GST) --pkg vte-$(VTEVERS) $(GUDEV)

LOPTS=-X -lm

#mwp-gresources.c: mwp-gresources.xml mwp.ui pixmaps/mwp_icon.svg
#	glib-compile-resources --target=$@ --generate-source  mwp-gresources.xml

mwp: $(SRCS) $(COMMON)
	./mkvers.sh
	$(VALAC) $(DOPTS) $(SPK) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f mwp *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s mwp $(prefix)/bin/mwp
	install -d $(datadir)/share/mwp
	install -m 644 $(COMMOND)/mwp_icon.svg $(datadir)/share/mwp/mwp_icon.svg
	install -d $(datadir)/share/icons/hicolor/scalable/apps/
	install -m 644 $(COMMOND)/mwp_icon.svg $(datadir)/share/icons/hicolor/scalable/apps/mwp_icon.svg
	install -m 644 $(COMMOND)/mwp_icon.svg $(datadir)/share/mwp/mwp.svg
	install -d $(datadir)/share/pixmaps
	install -m 644 $(COMMOND)/mwp_icon.svg $(datadir)/share/pixmaps/
	install -d $(datadir)/share/mwp/pixmaps
	install -m 644 $(COMMOND)/mwp_icon.svg $(datadir)/share/mwp/pixmaps/mwp_icon.svg
	install -m 644 mwp.ui menubar.ui $(datadir)/share/mwp/
	install -m 644 vcols.css $(datadir)/share/mwp/vcols.css
	install -m 644 default.layout $(datadir)/share/mwp/default.layout
	install -m 644 pixmaps/* $(datadir)/share/mwp/pixmaps/
	install -m 644 *.ogg $(datadir)/share/mwp/
	install -d $(datadir)/share/applications
	install -m 644 mwp.desktop $(datadir)/share/applications/mwp.desktop
	install -d $(datadir)/share/glib-2.0/schemas
	install -m 644 org.mwptools.planner.gschema.xml $(datadir)/share/glib-2.0/schemas/org.mwptools.planner.gschema.xml
	glib-compile-schemas $(datadir)/share/glib-2.0/schemas
	install -d $(datadir)/share/doc/mwp
	install -m 644 ../docs/mwptools.pdf $(datadir)/share/doc/mwp/mwptools.pdf
	install -d $(datadir)/$(BASH_COMPLETION_DIR)
	install -m 644 mwp_complete.sh $(datadir)/$(BASH_COMPLETION_DIR)/mwp
