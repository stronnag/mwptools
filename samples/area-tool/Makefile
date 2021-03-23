VALAC=valac

include ../../common.mk

APP=mwp-area-planner

APPS=$(APP)

all: $(APPS)

survey-resources.c: survey.gresources.xml survey.ui menubar.ui mwp_area_icon.svg
	glib-compile-resources --target=$@ --generate-source $<

SRCS= survey.vala survey-resources.c genpat.vala

COMMOND=../../common
MWPD=../../mwp

OPTS+= --vapidir $(COMMOND) -X -I$(COMMOND) --pkg mwpfuncs

COMMONM = $(MWPD)/settings.vala $(MWPD)/mapsources.vala $(MWPD)/mission.vala \
	$(COMMOND)/utils.vala  $(COMMOND)/mwplog.vala $(COMMOND)/xmlio.vala \
	$(COMMOND)/geocalc.vala $(COMMOND)/mspcmd.vala

PKGS= --pkg gtk+-3.0 --pkg atk --pkg clutter-1.0 --pkg champlain-gtk-0.12 \
	--pkg champlain-0.12 --pkg gio-2.0 --pkg posix --pkg clutter-gtk-1.0 \
	--pkg libsoup-2.4 --pkg libxml-2.0 --pkg mwpfuncs

LOPTS=-X -lm

$(APP) : $(SRCS) $(COMMONM)
	$(VALAC) $(OPTS) $(DOPTS) $(PKGS) -o $@  $^ $(LOPTS) $(MWIN)

genpat : genpat.vala
	$(VALAC) -D TEST genpat.vala -X -lm

clean:
	rm -f genpat $(APP)  *~ *.vala.c survey-resources.c

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
	install -d $(datadir)/share/mwp
	install -d $(datadir)/share/applications
	install -m 644 mwp-area-planner.desktop $(datadir)/share/applications/mwp-area-planner.desktop
	install -d $(datadir)/share/icons/hicolor/scalable/apps
	install -m 644 mwp_area_icon.svg $(datadir)/share/icons/hicolor/scalable/apps/mwp_area_icon.svg
