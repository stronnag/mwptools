VALAC=valac

include ../../common.mk

APP=ttycap

all: $(APP)

CLISRC=	ttycap.vala cserial.c

$(APP): $(CLISRC)
	$(VALAC)  $(DOPTS) $(OPTS)  --pkg posix $(CLISRC) -o $(APP)

clean:
	rm -f ttycap *~ *.vala.c

install: $(APP)
	@echo 'please copy ttycap ... to where ever you like'
