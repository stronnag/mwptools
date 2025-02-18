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

fixup-svg: fixup-svg.vala
	$(VALAC) $(OPTS) --pkg libxml-2.0 -o $@  $^

clean:
	rm -f $(APPS) fixup-svg
