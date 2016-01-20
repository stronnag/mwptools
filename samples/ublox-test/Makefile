VALAC=valac

include ../../common.mk


APP=ublox-geo
CLI=ublox-cli

all: $(APP) $(CLI)

CMN=../../common

CLISRC=	ublox.vapi ublox-cli.vala ublox-io.vala $(CMN)/mwplog.vala
ublox-cli: $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix --pkg gio-2.0 --pkg posix \
		$(CLISRC) -o ublox-cli


ublox-resources.c: ublox.gresources.xml
	glib-compile-resources --target=$@ --generate-source $^

SRCS= ublox-test.vala ublox-io.vala ublox.vapi settings.vala $(CMN)/utils.vala mapsources.vala $(CMN)/geocalc.vala $(CMN)/mwplog.vala ublox-resources.c

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg libsoup-2.4

LOPTS=-X -lm

$(APP) : $(SRCS)
	$(VALAC) $(OPTS) $(DOPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f ublox-cli ublox-geo  *~ *.vala.c

install: install-local

install-local:  ublox-cli ublox-geo
	../../installer.sh ublox-cli local
	../../installer.sh ublox-geo local

install-system: ublox-test
	../../installer.sh ublox-cli system
	../../installer.sh ublox-geo system
