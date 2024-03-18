VALAC=valac

include ../../common.mk
include ../../valaopts.mk

APP=mwplog-runner

all: $(APP)

COMMOND=../../common
LOPTS= -X -L$(prefix)/lib -X -lmwpvlib -X -lmwpclib -X -lm
OPTS+= --vapidir $(COMMOND) --vapidir $(prefix)/share/vala/vapi -X -I$(COMMOND) -X -I$(prefix)/include/
PKGS = --pkg mwpfuncs --pkg mwpvlib

PKGS += --pkg posix --pkg gio-2.0 --pkg linux --pkg json-glib-1.0
CLISRC=	$(APP).vala ../../mwp/mwp-replay.vala

$(APP): $(CLISRC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS)

clean:
	rm -f $(APP) *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
