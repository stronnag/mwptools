XOS := $(shell uname)

-include local.mk

ifeq ($(XOS),Linux)
 DOPTS += -D LINUX
 GUDEV = --pkg gudev-1.0
endif

OPTS += -X -O2 -X -s

VAPI := $(shell valac --api-version)

ifeq ($(VAPI),0.26)
 $(error toolset is obsolete)
endif
ifeq ($(VAPI),0.28)
  $(error toolset is obsolete)
endif
ifeq ($(VAPI),0.30)
 DOPTS += -D LSRVAL
 OPTS += --target-glib=2.48
endif
ifeq ($(VAPI),0.32)
 DOPTS += -D LSRVAL
 OPTS += --target-glib=2.48
endif
ifeq ($(VAPI),0.34)
 DOPTS += -D LSRVAL
endif

NOVTHREAD := $(shell pkg-config --atleast-version 0.43 $$(pkg-config --list-package-names  | grep libvala); echo $$?)

ifneq ($(NOVTHREAD), 0)
OPTS+= --thread
endif

USE_TERMCAP := $(shell pkg-config --exists ncurses; echo $$?)

GTKOK := $(shell pkg-config --atleast-version=3.22 gtk+-3.0; echo $$?)

ifneq ($(GTKOK), 0)
 DOPTS += -D OLDGTK
endif

VTEVERS=2.91

prefix?=$(DESTDIR)/usr
datadir?=$(DESTDIR)/usr
