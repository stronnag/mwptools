XOS := $(shell uname)

DOTPS=
ifeq ($(XOS),Linux)
 DOPTS += -D HAVE_FIONREAD
endif

VAPI := $(shell valac --api-version)
ifeq ($(VAPI),0.36)
 DOPTS += -D LSRREF
endif

TARGET=2.46
VTEVERS=2.91

OPTS += -X -O2 -X -s --thread --target-glib=$(TARGET)

prefix?=$(DESTDIR)/usr
datadir?=$(DESTDIR)/usr
