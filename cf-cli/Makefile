VALAC=valac

include ../common.mk

LOPTS=-X -lm
S1=cf-cli.vala cf-cli-serial.vala cserial.c
ifeq ($(XOS),Linux)
 S2=cf-cli-ui.vala cf-cli-serial.vala cf-cli.resources.c cserial.c devmanager_linux.vala
else
 S2=cf-cli-ui.vala cf-cli-serial.vala cf-cli.resources.c cserial.c devmanager-win32.vala
endif
all: cf-cli cf-cli-ui

cf-cli: $(S1)
	$(VALAC) $(OPTS) --pkg posix --pkg gio-2.0 $(S1) -o cf-cli

cf-cli.resources.c: cf-cli.resources.xml cf-cli.ui cf-cli.svg
	glib-compile-resources --generate-source  cf-cli.resources.xml

cf-cli-ui: $(S2)
	$(VALAC) $(OPTS) --pkg gudev-1.0 --pkg gtk+-3.0 $(S2) -o cf-cli-ui

clean:
	rm -f cf-cli cf-cli-ui  *.vala.c

install: install-local

install-local:  cf-cli cf-cli-ui
	../installer.sh cf-cli local
	../installer.sh cf-cli-ui local

install-system: cf-cli cf-cli-ui
	../installer.sh cf-cli system
	../installer.sh cf-cli-ui system
