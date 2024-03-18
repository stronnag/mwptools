VALAC=valac

include ../../common.mk
include ../../valaopts.mk

APP=ttycap

all: $(APP)

CLISRC=	ttycap.vala ../../clib/cserial.c
VAPI= --vapidir ../../common
OPTS+= -X -I../../common


$(APP): $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix $(CLISRC) $(VAPI) --pkg mwpfuncs -o $(APP)

clean:
	rm -f ttycap *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
