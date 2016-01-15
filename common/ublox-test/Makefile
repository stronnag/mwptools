VALAC=valac
OPTS+=-X -O2 --thread --target-glib=2.36

APP=ublox-geo
CLI=ublox-cli

all: $(APP) $(CLI)

ublox-cli: ublox-cli.vala ublox.vapi ublox.h
	$(VALAC) --pkg posix --pkg gio-2.0 --pkg posix \
		ublox.vapi ublox-cli.vala mwplog.vala -o ublox-cli


ublox-resources.c: ublox.gresources.xml
	glib-compile-resources --target=$@ --generate-source $^

SRCS= ublox-test.vala ublox-io.vala ublox.vapi settings.vala utils.vala mapsources.vala geocalc.vala mwplog.vala ublox-resources.c

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg libsoup-2.4

LOPTS=-X -lm

$(APP) : $(SRCS)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f ublox-cli ublox-geo  *~ *.vala.c

install: ublox-cli ublox-geo
	cp ublox-cli ublox-geo ~/bin/
