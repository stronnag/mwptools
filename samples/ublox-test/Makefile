VALAC=valac

include ../../common.mk

APP=ublox-geo
CLI=ublox-cli

APPS=$(APP) $(CLI)

all: $(APPS)

CLISRC=	ublox.vapi ublox-cli.vala ublox-io.vala init_signals.c

COMMONC= ../../common/mwplog.vala ../../common/cserial.c

ublox-cli: $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix --pkg gio-2.0 --pkg posix \
		$(CLISRC) $(COMMONC) -o ublox-cli

ublox-resources.c: ublox.gresources.xml
	glib-compile-resources --target=$@ --generate-source $^

SRCS= ublox-test.vala ublox-io.vala ublox.vapi ublox-resources.c

COMMONM = ../../common/cserial.c ../../mwp/settings.vala ../../mwp/mapsources.vala \
	../../common/utils.vala  ../../common/geocalc.vala ../../common/mwplog.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg libsoup-2.4

LOPTS=-X -lm

$(APP) : $(SRCS) $(COMMONM)
	$(VALAC) $(OPTS) $(DOPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f ublox-cli ublox-geo  *~ *.vala.c ublox-resources.c

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s $(CLI) $(prefix)/bin/$(CLI)
