VALAC=valac
OPTS=-X -O2 --target-glib=2.36 --thread
LOPTS=-X -lm

all: cf-cli cf-cli-ui

cf-cli: cf-cli.vala cf-cli-serial.vala cserial.c
	$(VALAC) $(OPTS) --pkg posix --pkg gio-2.0  cf-cli.vala cf-cli-serial.vala cserial.c -o cf-cli

cf-cli.resources.c: cf-cli.resources.xml cf-cli.ui cf-cli.svg
	glib-compile-resources --generate-source  cf-cli.resources.xml

cf-cli-ui: cf-cli-ui.vala cf-cli-serial.vala cf-cli.resources.c cserial.c devmanager_linux.vala
	$(VALAC) $(OPTS) --pkg gudev-1.0 --pkg gtk+-3.0 cf-cli-ui.vala cf-cli-serial.vala cf-cli.resources.c cserial.c devmanager_linux.vala

clean:
	rm -f cf-cli cf-cli-ui

install: install-local

install-local:  cf-cli
	../installer.sh cf-cli local
	../installer.sh cf-cli-ui local

install-system: cf-cli
	../installer.sh cf-cli system
	../installer.sh cf-cli system
