include ../common.mk
include ../valaopts.mk

VALAC = valac

COPTS = -X -D_XOPEN_SOURCE=701 -X -O2 -X -s


INCDIR ?= $(prefix)/include
VAPIDIR ?= $(prefix)/share/vala/vapi
LIBDIR ?= $(prefix)/lib

PKGS=--pkg mwpfuncs --pkg mwpvlib
PKGS += --pkg gio-2.0 --pkg posix

RPTH=
ifneq ("$(wildcard $(prefix)/lib/libmwpvlib.so)","")
  RPTH=-X -Wl,-rpath,$(prefix)/lib
endif

OPTS+= --vapidir $(VAPIDIR) -X -I$(INCDIR)
LOPTS= -X -L$(prefix)/lib -X -lmwpvlib -X -lmwpclib -X -lm $(RPTH)

APP=mwp-ble-bridge

all : $(APP)

$(APP): mwp-ble-bridge.vala socket-utils.vala
	$(VALAC) --define=TEST --define=LINUX $(COPTS) $(OPTS) $(PKGS) $(LOPTS) -o $@  $^

install: $(APP)
	install -s $(APP) $(prefix)/bin/

clean:
	rm -f  $(APP) *~
