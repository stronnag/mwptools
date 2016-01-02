CFLAGS=-O2 `pkg-config --cflags gtk+-2.0`
LDFLAGS=`pkg-config --libs gtk+-2.0`

mwp_ath: ath.c gtkartificialhorizon.c  gtkartificialhorizon.h
	$(CC) $(CFLAGS) ath.c gtkartificialhorizon.c -o mwp_ath $(LDFLAGS)
	cp mwp_ath ~/bin/

atest: atest.vala
	valac --pkg gtk+-3.0 --pkg posix atest.vala -X -lm

clean:
	rm -f mwp_ath atest

install: install-local

install-local: mwp_ath
	../installer.sh mwp_ath local

install-system: mwp_ath
	../installer.sh mwp_ath system
