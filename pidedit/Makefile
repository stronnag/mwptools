VALAC=valac
OPTS +=-X -O2 --target-glib=2.36
#LOPTS=-X -lbluetooth
LOPTS=
APP=pidedit
SRC=$(APP).vala
COMMON=../common/serial-device.vala ../common/utils.vala ../common/mspcmd.vala ../common/mspmsg.vala ../common/get_locale_double.c ../common/mwplog.vala
PKGS= --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg posix --pkg  json-glib-1.0 --pkg linux


$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP) *.vala.c

install: install-local

install-local: $(APP)
	../installer.sh $(APP) local

install-system: $(APP)
	../installer.sh $(APP) system
