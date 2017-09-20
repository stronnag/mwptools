VALAC=valac

include ../../common.mk
LOPTS=-X -lm

APP=mwplog-runner

all: $(APP)

COMMON=../../common/serial-device.vala ../../common/btdev.c \
        ../../common/cserial.c ../../common/mspcmd.vala  \
        ../../common/mspmsg.vala ../../common/mavcmd.vala ../../common/mwplog.vala

PKGS = --pkg posix --pkg gio-2.0 --pkg linux --pkg json-glib-1.0

CLISRC=	$(APP).vala ../../mwp/mwp-replay.vala  $(COMMON)

$(APP): $(CLISRC)
	$(VALAC) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS)

clean:
	rm -f $(APP) *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
