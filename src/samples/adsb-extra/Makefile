include vala.mk

VALAC = valac

OPTS += -X -O2 -X -s
PKGS=--pkg gio-2.0 --pkg posix

APPS=jsacsrv adsbpbsrv

all: $(APPS)

jsacsrv: jsacsrv.vala
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^

adsbpbsrv: adsbpbsrv.vala
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^

clean:
	rm -f $(APPS)
