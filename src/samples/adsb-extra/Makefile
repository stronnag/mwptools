include vala.mk

VALAC = valac

OPTS += -X -O2 -X -s
PKGS= --pkg gio-2.0

all: jsacsrv

jsacsrv: jsacsrv.vala
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^

clean:
	rm -f jsacsrv *~
