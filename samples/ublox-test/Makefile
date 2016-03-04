VALAC=valac

include ../../common.mk

APP=ublox-geo
CLI=ublox-cli

APPS=$(APP) $(CLI)

all: $(APPS)

CLISRC=	ublox.vapi ublox-cli.vala ublox-io.vala mwplog.vala cserial.c init_signals.c

ublox-cli: $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix --pkg gio-2.0 --pkg posix \
		$(CLISRC) -o ublox-cli


ublox-resources.c: ublox.gresources.xml
	glib-compile-resources --target=$@ --generate-source $^

SRCS= ublox-test.vala ublox-io.vala ublox.vapi settings.vala utils.vala mapsources.vala geocalc.vala mwplog.vala ublox-resources.c cserial.c

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg libsoup-2.4

LOPTS=-X -lm

$(APP) : $(SRCS)
	$(VALAC) $(OPTS) $(DOPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f ublox-cli ublox-geo  *~ *.vala.c

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
	install -s -D $(CLI) $(prefix)/bin/$(CLI)
