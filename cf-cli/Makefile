VALAC=valac

include ../common.mk

LOPTS=-X -lm
S1=cf-cli.vala cf-cli-serial.vala ../common/cserial.c
ifeq ($(XOS),Linux)
 S2=cf-cli-ui.vala cf-cli-serial.vala cf-cli.resources.c ../common/cserial.c devmanager_linux.vala
else
 S2=cf-cli-ui.vala cf-cli-serial.vala cf-cli.resources.c ../common/cserial.c devmanager-win32.vala
endif

CLI=cf-cli

ifdef VTEVERS
 APP=cf-cli-ui
endif
APPS=$(APP) $(CLI)

all: $(APPS)

cf-cli: $(S1)
	$(VALAC) $(OPTS) --pkg posix --pkg gio-2.0 $(S1) -o cf-cli

cf-cli.resources.c: cf-cli.resources.xml cf-cli.ui cf-cli.svg
	glib-compile-resources --generate-source  cf-cli.resources.xml

ifdef VTEVERS
cf-cli-ui: $(S2)
	$(VALAC) $(OPTS) --pkg gudev-1.0 --pkg gtk+-3.0 --pkg vte-$(VTEVERS) $(S2) -o cf-cli-ui
endif

clean:
	rm -f cf-cli cf-cli-ui  *.vala.c cf-cli.resources.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
ifdef VTEVERS
	install -s $(APP) $(prefix)/bin/$(APP)
endif
	install -s $(CLI) $(prefix)/bin/$(CLI)
