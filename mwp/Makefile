VALAC=valac
OPTS+=-X -O2 --thread --target-glib=2.36

APP=mwp

SRCS=mwp.vala liststore.vala mwp_markers.vala mwp_craft.vala settings.vala dialogs.vala mapsources.vala logger.vala espeak_wrapper.c mwp-replay.vala map_seeder.vala
COMMON=../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspmsg.vala ../common/mspcmd.vala  ../common/get_locale_double.c ../common/mwc.vala ../common/mwplog.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg libxml-2.0 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg gdl-3.0 --pkg pango --pkg libsoup-2.4

LOPTS=-X -lespeak -X -lm

$(APP) : $(SRCS) $(COMMON)
	$(VALAC) $(BBOPTS) $(SPOPTS) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

qproxy: qproxy.vala
	valac --pkg libsoup-2.4 --pkg posix  qproxy.vala

clean:
	rm -f mwp  *~ *.vala.c

install: install-local

install-local: $(TGT)
	../installer.sh $(APP) local

install-system: $(TGT)
	../installer.sh $APP system
