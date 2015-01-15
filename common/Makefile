VALAC=valac
OPTS=-X -O2 --target-glib=2.36
LOPTS=-X -lm

all: ublox-test

ublox-test: ublox-test.vala ublox.vapi ublox.h
	$(VALAC) --pkg posix --pkg gio-2.0 --pkg posix  ublox.vapi ublox-test.vala mwplog.vala -o ublox-test

#naze-cli: naze-cli.vala
#	$(VALAC) --pkg posix --pkg gio-2.0  naze-cli.vala mwplog.vala


clean:
	rm -f naze-cli ublox-test

install: install-local

install-local:  ublox-test cf-cli
	../installer.sh ublox-test local
	../installer.sh cf-cli local

install-system: ublox-test cf-cli
	../installer.sh ublox-test system
	../installer.sh cf-cli system
