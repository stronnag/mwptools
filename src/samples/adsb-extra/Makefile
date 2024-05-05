include vala.mk

VALAC = valac

OPTS += -X -O2 -X -s
PKGS=--pkg gio-2.0 --pkg posix

APPS=jsacsrv readsbpb jclient decode_readsb dtest

CFLAGS=-Wall -O2 -s
PBLIBS=-lprotobuf-c
DVOPTS=--vapidir=. --includedir=. -X -I.

all: $(APPS)

jsacsrv: jsacsrv.vala
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^

readsbpb: readsbpb.vala
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^

jclient: jclient.vala
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^


decode_readsb: decode_readsb.c readsb.pb-c.c
	$(CC) $(CFLAGS) -DTEST  -o $@ $^ $(PBLIBS)

dtest: dtest.vala readsb.pb-c.c decode_readsb.c
	$(VALAC) $(OPTS) $(DVOPTS) --pkg posix --pkg decode_readsb -X $(PBLIBS)  -o $@  $^

clean:
	rm -f $(APPS) dtest
