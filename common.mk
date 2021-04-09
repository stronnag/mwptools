XOS := $(shell uname)

-include local.mk

ifeq ($(XOS),Linux)
 DOPTS += -D LINUX
 GUDEV = --pkg gudev-1.0
endif

ifeq ($(XOS),Windows_NT)
 MWIN = -X -mwindows
endif

OPTS += -X -O2

ifeq ($(WARN),)
OPTS += -X -Wno-unused-result -X -Wno-format
 ifeq ($(XOS),FreeBSD)
  USE_CLANG=1
 endif
 ifeq ($(CC),clang)
  USE_CLANG=1
 endif
 ifeq ($(USE_CLANG),1)
  OPTS += -X -Wno-incompatible-pointer-types-discards-qualifiers -X -Wno-pointer-sign -X -Wno-incompatible-pointer-types -X -Wno-sentinel -X -Wno-deprecated-declarations -X -Wno-tautological-pointer-compare -X -Wno-void-pointer-to-enum-cast -X -Wno-unused-value
 else
  OPTS += -X -Wno-incompatible-pointer-types -X  -Wno-discarded-qualifiers -X -Wno-deprecated-declarations
 endif
endif

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

USE_URIPARSE := $(shell test $(VS) -ge 0050 ; echo $$? )

ifeq ($(USE_URIPARSE), 0)
 DOPTS+= -D USE_URIPARSE
endif

ifeq ($(USE_TV), 1)
 DOPTS+= -D USE_TV
endif

ifeq ($(USE_TV1), 1)
 DOPTS+= -D USE_TV1
endif

NOVTHREAD := $(shell V1=$$(valac --version | cut  -d '.' -f 2); V2=$$(valac --version | cut  -d '.' -f 3); VV=$$(printf "%02d%02d" $$V1 $$V2) ; [ $$VV -gt 4204 ] ; echo $$? )

ifneq ($(NOVTHREAD), 0)
 OPTS+= --thread
endif

USE_TERMCAP := $(shell pkg-config --exists ncurses; echo $$?)
USE_MQTT := $(shell test -f /usr/include/MQTTClient.h || test -f /usr/local/include/MQTTClient.h; echo $$?)
ifneq ($(USE_MQTT), 0)
 USE_MQTT := $(shell pkg-config --exists libmosquitto; echo $$?)
 ifeq ($(USE_MQTT), 0)
  MQTTLIB := $(or $(MQTTLIB),mosquitto)
 endif
else
 MQTTLIB := $(or $(MQTTLIB),paho)
endif


VTI := $(shell pkg-config --atleast-version=2.68 glib-2.0; echo $$?)
VT0 := $(shell test $(VS) -ge 0052 ; echo $$? )

ifeq ($(VT0), 1)
 DOPTS += -D OLDTVI
else
 ifeq ($(VT1), 1)
  DOPTS += -D OLDTVI
 endif
endif

VTEVERS=2.91

prefix?=$(DESTDIR)/usr
datadir?=$(DESTDIR)/usr
