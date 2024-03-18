VALAC=valac

include ../../common.mk
include ../../valaopts.mk

LOPTS=-X -lm
APP=mwp-inav-radar-sim
SRC=$(APP).vala
APP1=mwp-mavlink-traffic-sim
SRC1=$(APP1).vala

COMMOND=../../common
CLIB=../../clib
CLIBS= $(CLIB)/btdev.c $(CLIB)/cserial.c

DEVSRC=$(COMMOND)/devman.vala
ifeq ($(XOS),Linux)
DEVSRC += $(COMMOND)/usbmgr.vala $(COMMOND)/bluez.vala $(COMMOND)/bluetooth.vala $(COMMOND)/ble-helper.vala $(COMMOND)/btdevice.vala $(COMMOND)/ble_uuids.vala
endif

COMMON=$(COMMOND)/serial-device.vala $(COMMOND)/geocalc.vala  $(COMMOND)/utils.vala $(COMMOND)/mspcmd.vala  $(COMMOND)/mspmsg.vala $(COMMOND)/mwplog.vala $(COMMOND)/sede.vala $(COMMOND)/mwp_uriparser.vala $(DEVSRC) $(CLIBS)

PKGS=--pkg posix --pkg linux --pkg gio-2.0 --pkg mwpfuncs
PKGS+=--pkg gudev-1.0


OPTS+= --vapidir $(COMMOND) -X -I$(COMMOND)


all: $(APP) $(APP1)

$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

$(APP1): $(SRC1)  $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) $(APP1) *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP) $(APP1)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s $(APP1) $(prefix)/bin/$(APP1)
