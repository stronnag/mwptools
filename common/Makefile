VALAC=valac
OPTS=-X -O2 --target-glib=2.36 --thread
LOPTS=-X -lm

all: ublox-test

ublox-test: ublox-test.vala ublox.vapi ublox.h
	$(VALAC) --pkg posix --pkg gio-2.0 --pkg posix  ublox.vapi ublox-test.vala mwplog.vala -o ublox-test

clean:
	rm -f ublox-test

install: install-local

install-local:  ublox-test
	../installer.sh ublox-test local

install-system: ublox-test
	../installer.sh ublox-test system
