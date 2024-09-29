include ../../common.mk
include ../../valaopts.mk

APP=mwp-inav-radar-sim
SRC=$(APP).vala
APP1=mwp-mavlink-traffic-sim
SRC1=$(APP1).vala

INCDIR ?= $(prefix)/include
VAPIDIR ?= $(prefix)/share/vala/vapi
LIBDIR ?= $(prefix)/lib

PKGS=--pkg posix --pkg linux --pkg gio-2.0 --pkg mwpfuncs --pkg mwpvlib
PKGS+=--pkg gudev-1.0

LOPTS= -X -L$(prefix)/lib -X -lmwpvlib -X -lmwpclib -X -lm
OPTS+= --vapidir $(VAPIDIR) -X -I$(INCDIR)

RPTH=
ifneq ("$(wildcard $(prefix)/lib/libmwpvlib.so)","")
	RPTH=-X -Wl,-rpath,$(prefix)/lib
endif

all: $(APP) $(APP1)

$(APP): $(SRC)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS) $(RPTH)

$(APP1): $(SRC1)  $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS) $(RPTH)

clean:
	rm -f $(APP) $(APP1) *.vala.c

install: $(APP) $(APP1)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s $(APP1) $(prefix)/bin/$(APP1)
