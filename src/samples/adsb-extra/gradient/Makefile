include ../vala.mk

OPTS+=-X -O2 -X -s
PKGS=--pkg libxml-2.0 --pkg gtk4 --pkg gio-2.0

all: read_svg

read_svg: read_svg.vala
	valac $(OPTS) $(PKGS) -o $@  $^

clean:
	rm read_svg *~
