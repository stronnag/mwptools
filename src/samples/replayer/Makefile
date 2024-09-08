VALAC=valac

include ../../common.mk
include ../../valaopts.mk

APP=mwplog-runner

all: $(APP)

INCDIR ?= $(prefix)/include
VAPIDIR ?= $(prefix)/share/vala/vapi
LIBDIR ?= $(prefix)/lib

PKGS += --pkg mwpfuncs --pkg mwpvlib
PKGS += --pkg posix --pkg gio-2.0 --pkg linux --pkg json-glib-1.0

RPTH=
ifneq ("$(wildcard $(prefix)/lib/libmwpvlib.so)","")
  RPTH=-X -Wl,-rpath,$(prefix)/lib
endif

LOPTS= -X -L$(prefix)/lib -X -lmwpvlib -X -lmwpclib -X -lm
OPTS+= --vapidir $(VAPIDIR) -X -I$(INCDIR)

CLISRC=	$(APP).vala mwp-replay.vala

$(APP): $(CLISRC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(RPTH)

clean:
	rm -f $(APP) *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
