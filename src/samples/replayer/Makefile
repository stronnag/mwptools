VALAC=valac

include ../../common.mk
include ../../valaopts.mk
LOPTS=-X -lm

APP=mwplog-runner

all: $(APP)
COMMOND=../../common
CLIB=../../clib
CLIBS=$(CLIB)/btdev.c $(CLIB)/cserial.c

DEVSRC=$(COMMOND)/devman.vala
ifeq ($(XOS),Linux)
DEVSRC += $(COMMOND)/usbmgr.vala $(COMMOND)/bluez.vala $(COMMOND)/bluetooth.vala \
	$(COMMOND)/ble-helper.vala $(COMMOND)/btdevice.vala $(COMMOND)/ble_uuids.vala
endif


COMMON=$(COMMOND)/serial-device.vala $(COMMOND)/mspcmd.vala $(COMMOND)/mspmsg.vala \
	$(COMMOND)/mavcmd.vala $(COMMOND)/mwplog.vala $(COMMOND)/sede.vala \
	$(COMMOND)/mwp_uriparser.vala

COMMON += $(CLIBS) $(DEVSRC)

PKGS = --pkg posix --pkg gio-2.0 --pkg linux --pkg json-glib-1.0 --pkg mwpfuncs

CLISRC=	$(APP).vala ../../mwp/mwp-replay.vala  $(COMMON)

OPTS+=--vapidir=$(COMMOND) -X -I$(COMMOND)

$(APP): $(CLISRC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS)

clean:
	rm -f $(APP) *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
