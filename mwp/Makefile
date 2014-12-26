VALAC=valac
OPTS+=-X -O2 --thread --target-glib=2.36
## -g --save-temps

APP=mwp

TGT=$(APP)
ifeq (1, ${U})
  TGT = mwpu
endif

SRCS=mwp.vala liststore.vala mwp_markers.vala mwp_craft.vala settings.vala dialogs.vala mapsources.vala logger.vala espeak_wrapper.c mwp-replay.vala stupid_ubuntu_atexit.c map_seeder.vala
COMMON=../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspmsg.vala ../common/mspcmd.vala  ../common/get_locale_double.c ../common/mwc.vala ../common/mwplog.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 --pkg champlain-0.12 --pkg libxml-2.0 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 --pkg gdl-3.0 --pkg pango --pkg libsoup-2.4

#LOPTS=-X -lbluetooth -X -lm -X -lespeak
LOPTS=-X -lespeak -X -lm

$(APP) : $(SRCS) $(COMMON)
	$(VALAC) $(NOBB) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

mwpu : $(SRCS) $(COMMON)
	$(VALAC) -D NOBB $(OPTS) $(PKGS) -o mwp  $^ $(LOPTS)

clean:
	rm -f mwp  *~ *.vala.c

install: install-local

install-local: $(TGT)
	../installer.sh $(APP) local

install-system: $(TGT)
	../installer.sh $APP system
