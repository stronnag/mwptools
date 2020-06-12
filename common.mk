XOS := $(shell uname)

-include local.mk

ifeq ($(XOS),Linux)
 DOPTS += -D LINUX
 GUDEV = --pkg gudev-1.0
endif

ifeq ($(OS),Windows_NT)
 MWIN = -X -mwindows
endif

OPTS += -X -O2

ifeq ($(origin DEBUG), undefined)
 OPTS += -X -s
else
 OPTS += -g
endif

VAPI := $(shell valac --api-version)

VS := $(shell V1=$$(echo $(VAPI) | cut  -d '.' -f 1); V2=$$(echo $(VAPI) | cut  -d '.' -f 2); printf "%02d%02d" $$V1 $$V2)

VALID_API := $(shell test $(VS) -ge 0038 ; echo $$? )

ifneq ($(VALID_API), 0)
 $(error Vala toolset is obsolete)
endif

USE_TV := $(shell test $(VS) -ge 0046 ; echo $$? )
USE_TV1 := $(shell test $(VS) -ge 0040 ; echo $$? )

ifeq ($(USE_TV), 1)
 DOPTS+= -D USE_TV
endif

ifeq ($(USE_TV1), 1)
 DOPTS+= -D USE_TV1
endif

#ifeq ($(VAPI),0.34)
# DOPTS += -D LSRVAL
#endif

NOVTHREAD := $(shell V1=$$(valac --version | cut  -d '.' -f 2); V2=$$(valac --version | cut  -d '.' -f 3); VV=$$(printf "%02d%02d" $$V1 $$V2) ; [ $$VV -gt 4204 ] ; echo $$? )

ifneq ($(NOVTHREAD), 0)
 OPTS+= --thread
endif

USE_TERMCAP := $(shell pkg-config --exists ncurses; echo $$?)

#GTKOK := $(shell pkg-config --atleast-version=3.22 gtk+-3.0; echo $$?)
#ifneq ($(GTKOK), 0)
# DOPTS += -D OLDGTK
#endif

VTEVERS=2.91

prefix?=$(DESTDIR)/usr
datadir?=$(DESTDIR)/usr
