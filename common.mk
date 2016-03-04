XOS := $(shell uname)

DOTPS=
ifeq ($(XOS),Linux)
 DOPTS += -D HAVE_FIONREAD
endif

PKG_INFO := $(shell pkg-config --atleast-version=2.48 libsoup-2.4; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D BADSOUP
 QPROXY = yes
 APPS += qproxy
endif

PKG_INFO := $(shell pkg-config --atleast-version=0.12.3 champlain-0.12; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D NOBB
endif

PKG_INFO := $(shell pkg-config --atleast-version=0.30 libvala-0.30 && pkg-config --atleast-version=2.46 glib-2.0; echo $$?)
ifneq ($(PKG_INFO),0)
 DOPTS += -D NOPUSHFRONT
 TARGET=2.36
else
 TARGET=2.46
endif

OPTS += -X -O2 -X -s --thread --target-glib=$(TARGET)

prefix?=/usr
datadir?=/usr
