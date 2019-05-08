VALAC=valac

include ../../common.mk

LOPTS=-X -lm
APP=mwp-radar-sim
SRC=$(APP).vala

COMMOND=../../common

COMMON=$(COMMOND)/serial-device.vala $(COMMOND)/geocalc.vala  $(COMMOND)/utils.vala $(COMMOND)/mspcmd.vala  $(COMMOND)/mspmsg.vala $(COMMOND)/mwplog.vala  $(COMMOND)/btdev.c $(COMMOND)/cserial.c

PKGS=--pkg posix --pkg linux --pkg gio-2.0

OPTS+= --vapidir $(COMMOND) -X -I$(COMMOND) --pkg mwpfuncs

$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
