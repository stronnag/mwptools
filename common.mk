XOS := $(shell uname)

DOTPS=
ifeq ($(XOS),Linux)
 DOPTS += -D HAVE_FIONREAD
endif

TARGET=2.46
VTEVERS=2.91

OPTS += -X -O2 -X -s --thread

prefix?=$(DESTDIR)/usr
datadir?=$(DESTDIR)/usr
