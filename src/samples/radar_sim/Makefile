VALAC=valac

include ../../common.mk

LOPTS=-X -lm
APP=mwp-inav-radar-sim
SRC=$(APP).vala
APP1=mwp-mavlink-traffic-sim
SRC1=$(APP1).vala

COMMOND=../../common

COMMON=$(COMMOND)/serial-device.vala $(COMMOND)/geocalc.vala  $(COMMOND)/utils.vala $(COMMOND)/mspcmd.vala  $(COMMOND)/mspmsg.vala $(COMMOND)/mwplog.vala  $(COMMOND)/btdev.c $(COMMOND)/cserial.c $(COMMOND)/sede.vala

PKGS=--pkg posix --pkg linux --pkg gio-2.0

OPTS+= --vapidir $(COMMOND) -X -I$(COMMOND) --pkg mwpfuncs

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
