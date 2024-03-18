include ../common.mk
include ../valaopts.mk

VALAC = valac

COPTS = -X -D_XOPEN_SOURCE=701
OPTS +=  -X -O2 -X -s
COMMOND=../common
LOPTS= -X -L$(prefix)/lib -X -lmwpvlib #-X -lmwpclib
OPTS+= --vapidir $(COMMOND) --vapidir $(prefix)/share/vala/vapi -X -I$(COMMOND) -X -I$(prefix)/include/
PKGS = --pkg mwpfuncs --pkg mwpvlib

PKGS += --pkg gio-2.0 --pkg posix
APP=mwp-ble-bridge

all : $(APP)

$(APP): mwp-ble-bridge.vala socket-utils.vala
	$(VALAC) --define=TEST --define=LINUX $(COPTS) $(OPTS) $(PKGS) $(LOPTS) -o $@  $^

install: $(APP)
	install -s $(APP) $(prefix)/bin/

clean:
	rm -f  $(APP) *~
