XOS := $(shell uname)

-include local.mk

ifeq ($(XOS),Linux)
 DOPTS += -D HAVE_FIONREAD -D LINUX
 GUDEV = --pkg gudev-1.0
endif

VAPI := $(shell valac --api-version)

ifeq ($(VAPI),0.26)
 $(error toolset is obsolete)
endif
ifeq ($(VAPI),0.28)
  $(error toolset is obsolete)
endif
ifeq ($(VAPI),0.30)
  $(error toolset is obsolete)
endif
ifeq ($(VAPI),0.32)
  $(error toolset is obsolete)
endif
ifeq ($(VAPI),0.34)
 DOPTS += -D LSRVAL
endif

USE_TERMCAP := $(shell pkg-config --exists ncurses; echo $$?)

GTKOK := $(shell pkg-config --atleast-version=3.22 gtk+-3.0; echo $$?)

ifneq ($(GTKOK), 0)
 DOPTS += -D OLDGTK
endif

VTEVERS=2.91

OPTS += -X -O2 -X -s --thread

prefix?=$(DESTDIR)/usr
datadir?=$(DESTDIR)/usr
