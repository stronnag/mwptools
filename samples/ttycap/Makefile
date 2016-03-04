VALAC=valac

include ../../common.mk

APP=ttycap

all: $(APP)

CLISRC=	ttycap.vala cserial.c

$(APP): $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix $(CLISRC) -o $(APP)

clean:
	rm -f ttycap *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
