VALAC = valac

COPTS = -X -D_XOPEN_SOURCE=701
OPTS=-X -O2 -X -s
OPTS += -X -Wno-unused-result -X -Wno-format -X -Wno-implicit-function-declaration
OPTS += -X -Wno-incompatible-pointer-types -X  -Wno-discarded-qualifiers -X -Wno-deprecated-declarations
#CLANGOPTS += -X -Wno-pointer-type-mismatch -X -Wno-incompatible-pointer-types-discards-qualifiers -X -Wno-tautological-pointer-compare

PKGS = --pkg gio-2.0 --pkg posix
C = ../common
COMSRC = $(C)/bluetooth.vala  $(C)/bluez.vala $(C)/btdevice.vala $(C)/ble-helper.vala $(C)/ble_uuids.vala

all : mwp-ble-bridge

mwp-ble-bridge: mwp-ble-bridge.vala socket-utils.vala $(COMSRC)
	$(VALAC) --define=TEST --define=LINUX $(COPTS) $(OPTS) $(PKGS) -o $@  $^

clean:
	rm -f  mwp-ble-bridge *~
