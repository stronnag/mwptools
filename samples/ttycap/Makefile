VALAC=valac

include ../../common.mk

APP=ttycap

all: $(APP)

CLISRC=	ttycap.vala ../../common/cserial.c
VAPI= --vapidir ../../common
OPTS+= -X -I../../common


$(APP): $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix $(CLISRC) $(VAPI) --pkg mwpfuncs -o $(APP)

clean:
	rm -f ttycap *~ *.vala.c

install: $(APPS)
	install -s -D $(APP) $(prefix)/bin/$(APP)
