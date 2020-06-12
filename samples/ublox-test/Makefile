VALAC=valac

include ../../common.mk

APP=ublox-geo
CLI=ublox-cli

APPS=$(APP) $(CLI)

all: $(APPS)

CLISRC=	ublox.vapi ublox-cli.vala ublox-io.vala init_signals.c
COMMOND=../../common
MWPD=../../mwp

VAPI= --vapidir $(COMMOND)
COMMONC= $(COMMOND)/mwplog.vala $(COMMOND)/cserial.c
OPTS+= -X -I$(COMMOND) $(VAPI)

ublox-cli: $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix --pkg gio-2.0 --pkg mwpfuncs \
		$(CLISRC) $(COMMONC) -o ublox-cli

ublox-resources.c: ublox.gresources.xml ublox-test.ui ublox.png
	glib-compile-resources --target=$@ --generate-source $<

SRCS= ublox-test.vala ublox-io.vala ublox.vapi ublox-resources.c

COMMONM = $(COMMOND)/cserial.c $(MWPD)/settings.vala $(MWPD)/mapsources.vala \
	$(COMMOND)/utils.vala  $(COMMOND)/geocalc.vala $(COMMOND)/mwplog.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 \
	--pkg champlain-0.12 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 \
	--pkg libsoup-2.4 --pkg mwpfuncs

LOPTS=-X -lm

$(APP) : $(SRCS) $(COMMONM)
	$(VALAC) $(OPTS) $(DOPTS) $(PKGS) -o $@ $^ $(LOPTS) $(MWIN)

clean:
	rm -f ublox-cli ublox-geo  *~ *.vala.c ublox-resources.c

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s $(CLI) $(prefix)/bin/$(CLI)
