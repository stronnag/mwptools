include ../common.mk
include ../valaopts.mk

all: gmproxy

prefix ?= $(HOME)/.local
OPTS ?= -X -O3 -X -s

gmproxy: gmproxy.vala
	valac $(OPTS) --pkg libsoup-3.0 --pkg posix --pkg gio-2.0 -o $@  $^


bproxy: bproxy.vala
	valac $(OPTS) --pkg libsoup-3.0 --pkg posix --pkg gio-2.0 -o $@  $^

gmproxy2: gmproxy.vala
	valac $(OPTS) -D COLDSOUP  --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o $@  $^


bproxy2: bproxy.vala
	valac $(OPTS) -D COLDSOUP --pkg libsoup-2.4 --pkg posix --pkg gio-2.0 -o $@  $^

clean:
	rm -f gmproxy qproxy gmproxy2 qproxy2 bproxy bproxy2 *~ *.vala.c

install: $(APP)
	install -d $(prefix)/bin
	install -s gmproxy $(prefix)/bin/gmproxy
	install -s bproxy $(prefix)/bin/bproxy
