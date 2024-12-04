##include ../common.mk
include ./vala.mk

XOS := $(shell uname -m)

APP = gmproxy bproxy

all: $(APP)

prefix ?= $$HOME/.local
OPTS += -X -O3 -X -s

ifeq ($(XOS),Msys)
 OPTS += -D WINDOWS
else
 OPTS += -D UNIX
endif

gmproxy: gmproxy.vala
	valac $(OPTS) --pkg libsoup-3.0 --pkg posix --pkg gio-2.0 -o $@  $^

bproxy: bproxy.vala
	valac $(OPTS) --pkg libsoup-3.0 --pkg posix --pkg gio-2.0 -o $@  $^

clean:
	rm -f gmproxy qproxy gmproxy2 qproxy2 bproxy bproxy2 *~ *.vala.c

install: $(APP)
	install -d $(prefix)/bin
	install -s gmproxy $(prefix)/bin/gmproxy
	install -s bproxy $(prefix)/bin/bproxy
