include ../common.mk

all: gmproxy

# This is unadulated evil, and it's all Ubuntu 1.4.04 LTS's fault

gmproxy: gmproxy.vala
	valac $(OPTS) --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o gmproxy gmproxy.vala


bproxy: bproxy.vala
	valac $(OPTS) --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o $@  $^

clean:
	rm -f gmproxy qproxy *~ *.vala.c

install: $(APP) gmproxy
	install -d $(prefix)/bin
	install -s gmproxy $(prefix)/bin/gmproxy
