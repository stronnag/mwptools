VALAC=valac
OPTS=-X -O2 --target-glib=2.36
#LOPTS=-X -lm -X -lbluetooth
LOPTS=-X -lm
APP=mspsim
SRC=$(APP).vala
COMMON=../common/mwp_xml.vala ../common/serial-device.vala ../common/geocalc.vala  ../common/utils.vala ../common/mspcmd.vala  ../common/mspmsg.vala ../common/get_locale_double.c

PKGS=--pkg posix --pkg linux --pkg gio-2.0 --pkg gtk+-3.0 --pkg libxml-2.0 --pkg json-glib-1.0

$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP)

install: install-local

install-local: $(APP)
	../installer.sh $(APP) local

install-system: $(APP)
	../installer.sh $APP system
