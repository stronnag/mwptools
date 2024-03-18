include ../../common.mk
include ../../valaopts.mk

APP=mwp-inav-radar-sim
SRC=$(APP).vala
APP1=mwp-mavlink-traffic-sim
SRC1=$(APP1).vala

COMMOND=../../common
CLIB=../../clib

PKGS=--pkg posix --pkg linux --pkg gio-2.0 --pkg mwpfuncs --pkg mwpvlib
PKGS+=--pkg gudev-1.0

LOPTS= -X -L$(prefix)/lib -X -lmwpvlib -X -lmwpclib -X -lm
OPTS+= --vapidir $(COMMOND) --vapidir $(prefix)/share/vala/vapi -X -I$(COMMOND) -X -I$(prefix)/include/


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
