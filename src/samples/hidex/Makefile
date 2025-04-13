prefix ?=$$HOME/.local
OOS := $(shell uname -o)

ifeq ($(OOS),Msys)
 WINDOWS=-D WINDOWS
 GIOOS=--pkg gio-windows-2.0
else
 GIOOS=--pkg gio-unix-2.0
endif

all: mwp-hid-server mwp-hid-test mwp-hid-cli

mwp-hid-test: mwp-hid-test.vala
	valac -X -O2 -X -s --pkg sdl2  -o $@  $^

mwp-hid-server: mwp-hid-server.vala  hid-reader.vala
	valac $(WINDOWS) -X -O2 -X -s --pkg sdl2 --pkg gio-2.0  -X -lm -o $@  $^

mwp-hid-cli: mwp-hid-cli.vala
	valac --pkg readline --pkg gio-2.0 -X -O2 -X -s -X -lreadline -o $@  $^

clean:
	rm -f  mwp-hid-server mwp-hid-test mwp-hid-cli *.exe *~

install:  mwp-hid-server mwp-hid-test mwp-hid-cli
	install -d $(prefix)/bin
	install -s mwp-hid-server $(prefix)/bin/mwp-hid-server
	install -s mwp-hid-test $(prefix)/bin/mwp-hid-test
	install -s mwp-hid-test $(prefix)/bin/mwp-hid-cli
