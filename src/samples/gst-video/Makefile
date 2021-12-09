ALL = gst-devmon gst-video-player

prefix ?= $(HOME)/.local

all: $(ALL)

OPTS=-X -O3 -X -s

gst-video-player: gst-video-player.vala
	valac $(OPTS) -D TEST --pkg gtk+-3.0 --pkg gstreamer-1.0 --pkg gstreamer-pbutils-1.0 gst-video-player.vala

gst-devmon: gst-devmon.vala
	valac $(OPTS) -D TEST --pkg gstreamer-1.0 --pkg gio-2.0 --pkg gudev-1.0 gst-devmon.vala

install: $(ALL)
	install -d $(prefix)/bin
	install $(ALL) $(prefix)/bin/

clean:
	rm -f $(ALL)
