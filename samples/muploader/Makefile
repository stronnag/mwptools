VALAC=valac

include ../../common.mk

CLI=mwp-uploader
APPS=$(CLI)

COMMOND=../../common
MWPD=../../mwp

COMMONC=$(COMMOND)/serial-device.vala $(COMMOND)/btdev.c \
	$(COMMOND)/cserial.c $(COMMOND)/mspcmd.vala $(COMMOND)/mwplog.vala \
	$(COMMOND)/mspmsg.vala $(COMMOND)/devman.vala \
	$(COMMOND)/xmlio.vala $(COMMOND)/json_io.vala \
	$(MWPD)/mission.vala $(COMMOND)/geocalc.vala

PKGS = --pkg posix --pkg gio-2.0 --pkg linux --pkg mwpfuncs
PKGSR = --pkg gio-2.0 $(GUDEV) --pkg libxml-2.0 --pkg json-glib-1.0

OPTS+=--vapidir=$(COMMOND) -X -I$(COMMOND) -X -lm

all: $(CLI)

$(CLI): muppet.vala $(COMMONC)
	$(VALAC) $(DOPTS) $(OPTS) -o $@  $^ $(LOPTS) $(PKGS) $(PKGSR)

clean:
	rm -f $(CLI) *.vala.c *~

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(CLI) $(prefix)/bin/$(CLI)
