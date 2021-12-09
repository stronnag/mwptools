include ../common.mk

all: gmproxy

prefix ?= $(HOME)/.local
OPTS ?= -X -O3 -X -s

gmproxy: gmproxy.vala
	valac $(OPTS) --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o gmproxy gmproxy.vala


bproxy: bproxy.vala
	valac $(OPTS) --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o $@  $^

clean:
	rm -f gmproxy qproxy *~ *.vala.c

install: $(APP)
	install -d $(prefix)/bin
	install -s gmproxy $(prefix)/bin/gmproxy
