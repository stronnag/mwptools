include ../common.mk

SRC=
ifdef QPROXY
SRC=qproxy
else
SRC=genproxy
endif
APP=qproxy

all: $(APP) gmproxy

# This is unadulated evil, and it's all Ubuntu 1.4.04 LTS's fault

$(APP): $(SRC).vala
	valac $(OPTS) --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o $(APP) $(SRC).vala

gmproxy: gmproxy.vala
	valac $(OPTS) --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o gmproxy gmproxy.vala


bproxy: bproxy.vala
	valac $(OPTS) --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o $@  $^

clean:
	rm -f gmproxy qproxy *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP) gmproxy
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -s gmproxy $(prefix)/bin/gmproxy
