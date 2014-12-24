VALAC=valac
OPTS=-X -O2 --target-glib=2.36
LOPTS=-X -lm

all: ublox-test naze-cli

ublox-test: ublox-test.vala ublox.vapi ublox.h
	$(VALAC) --pkg posix --pkg gio-2.0 --pkg posix  ublox.vapi ublox-test.vala -o ublox-test

naze-cli: naze-cli.vala
	$(VALAC) --pkg posix --pkg gio-2.0  naze-cli.vala

clean:
	rm -f naze-cli ublox-test

install: install-local

install-local:  ublox-test naze-cli
	../installer.sh ublox-test local
	../installer.sh naze-cli local

install-system: ublox-test naze-cli
	../installer.sh ublox-test system
	../installer.sh naze-cli system
