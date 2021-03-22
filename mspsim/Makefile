VALAC=valac

include ../common.mk

LOPTS=-X -lm
APP=mspsim
SRC=$(APP).vala

COMMOND=../common

COMMON=$(COMMOND)/mwp_xml.vala $(COMMOND)/serial-device.vala $(COMMOND)/geocalc.vala  $(COMMOND)/utils.vala $(COMMOND)/mspcmd.vala  $(COMMOND)/mspmsg.vala $(COMMOND)/mwplog.vala  $(COMMOND)/btdev.c $(COMMOND)/cserial.c

PKGS=--pkg posix --pkg linux --pkg gio-2.0 --pkg gtk+-3.0 --pkg libxml-2.0 --pkg json-glib-1.0

OPTS+= --vapidir $(COMMOND) -X -I$(COMMOND) --pkg mwpfuncs

$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(DOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) *.vala.c

install: $(APP)
	install -d $(prefix)/bin
	install -d $(datadir)/share/$(APP)
	install -d $(datadir)/share/applications
	install -s $(APP) $(prefix)/bin/$(APP)
	install -m 644 $(COMMOND)/mwp_icon.svg $(datadir)/share/$(APP)/mwp_icon.svg
	install -m 644 $(COMMOND)/mwp_icon.svg $(datadir)/share/$(APP)/$(APP)_icon.svg
	install -m 644 $(APP).ui $(datadir)/share/$(APP)/$(APP).ui
	install -m 644 $(APP).desktop $(datadir)/share/applications/$(APP).desktop
