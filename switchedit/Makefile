VALAC=valac
OPTS +=-X -O2 --target-glib=2.36
LOPTS=-X -lbluetooth
APP=switchedit
SRC=$(APP).vala
COMMON=../common/serial-device.vala ../common/utils.vala ../common/mspcmd.vala ../common/cserial.c ../common/mspmsg.vapi
PKGS= --pkg posix --pkg gio-2.0 --pkg gtk+-3.0 --pkg posix

$(APP): $(SRC)  $(COMMON)
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^ $(LOPTS)

clean:
	rm -f $(APP)

install: install-local

install-local: $(APP)
	../installer.sh $(APP) local

install-system: $(APP)
	../installer.sh $(APP) system
