XOS := $(shell uname)

DOTPS=
ifeq ($(XOS),Linux)
 DOPTS += -D HAVE_FIONREAD
endif

PKG_INFO := $(shell pkg-config --atleast-version=2.48 libsoup-2.4; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D BADSOUP
 QPROXY = yes
endif

PKG_INFO := $(shell pkg-config --atleast-version=0.12.3 champlain-0.12; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D NOBB
endif


VAPI := $(shell valac --api-version)
PKG_INFO := $(shell pkg-config --atleast-version=0.30 libvala-$(VAPI) && pkg-config --atleast-version=2.46 glib-2.0; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D NOPUSHFRONT
 TARGET=2.36
else
 TARGET=2.46
endif

PKG_INFO := $(shell pkg-config --exists vte-2.91; echo $$?)
ifeq ($(PKG_INFO),0)
 VTEVERS=2.91
else
 PKG_INFO := $(shell pkg-config --exists vte-2.90; echo $$?)
 ifeq ($(PKG_INFO),0)
  VTEVERS=2.90
 endif
endif

OPTS += -X -O2 -X -s --thread --target-glib=$(TARGET)

prefix?=$(DESTDIR)/usr
datadir?=$(DESTDIR)/usr
