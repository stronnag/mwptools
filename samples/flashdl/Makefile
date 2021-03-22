VALAC=valac

include ../../common.mk

CLI=flashdl

COMMOND=../../common
COMMONC=$(COMMOND)/serial-device.vala $(COMMOND)/btdev.c \
        $(COMMOND)/cserial.c $(COMMOND)/mspcmd.vala $(COMMOND)/mwplog.vala \
        $(COMMOND)/mspmsg.vala $(COMMOND)/devman.vala $(COMMOND)/mwptermcap.vala

PKGS = --pkg posix --pkg gio-2.0 --pkg linux --pkg mwpfuncs $(GUDEV)
OPTS+=--vapidir=$(COMMOND) -X -I$(COMMOND)

ifeq ($(USE_TERMCAP),0)
 LOPTS+= -X -lncurses
endif

APP=$(CLI)

all: $(APP)


flashdl: flashdl.vala $(COMMONC)
	$(VALAC) $(DOPTS) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS)

clean:
	rm -f flashdl *.vala.c *~

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
