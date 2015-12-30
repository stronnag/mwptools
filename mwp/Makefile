VALAC=valac

APPS=mwp

XOS := $(shell uname)

DOTPS=
ifeq ($(XOS),Linux)
 DOPTS += -D HAVE_FIONREAD
endif

PKG_INFO := $(shell pkg-config --atleast-version=2.48 libsoup-2.4; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D BADSOUP
 QPROXY = yes
 APPS += qproxy
endif

PKG_INFO := $(shell pkg-config --atleast-version=0.12.3 champlain-0.12; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D NOBB
endif

PKG_INFO := $(shell pkg-config --atleast-version=0.30 libvala-0.30 && pkg-config --atleast-version=2.46 glib-2.0; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D NOPUSHFRONT
 TARGET=2.36
else
 TARGET=2.46
endif

OPTS+=-X -O2 --thread --target-glib=$(TARGET)

all: $(APPS)

SRCS=mwp.vala liststore.vala mwp_markers.vala mwp_craft.vala settings.vala dialogs.vala mapsources.vala logger.vala espeak_wrapper.c mwp-replay.vala map_seeder.vala mwp-layout.vala layout-test.vala iparser.vala

COMMON=../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspmsg.vala ../common/mspcmd.vala  ../common/get_locale_double.c ../common/mwc.vala ../common/mwplog.vala ../common/mavcmd.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg libxml-2.0 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg gdl-3.0 --pkg pango --pkg libsoup-2.4 --pkg linux --pkg gstreamer-0.10

LOPTS=-X -lespeak -X -lm

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
