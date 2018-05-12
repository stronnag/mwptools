VALAC=valac

include ../../common.mk
LOPTS=-X -lm

APP=mwplog-runner

all: $(APP)
COMMOND=../../common

COMMON=$(COMMOND)/serial-device.vala $(COMMOND)/btdev.c \
        $(COMMOND)/cserial.c $(COMMOND)/mspcmd.vala  \
        $(COMMOND)/mspmsg.vala $(COMMOND)/mavcmd.vala $(COMMOND)/mwplog.vala

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
