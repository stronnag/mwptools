DIRS = mspsim pidedit switchedit samples/ublox-test cf-cli horizon mwp bbox-replay
INSTALLDIRS = $(DIRS:%=install-%)
LOCALDIRS = $(DIRS:%=local-%)
CLEANDIRS = $(DIRS:%=clean-%)

all: $(DIRS)
$(DIRS):
	$(MAKE) -C $@

sysinstall: install

install: $(INSTALLDIRS)
$(INSTALLDIRS):
	$(MAKE) -C $(@:install-%=%) install

local: $(LOCALDIRS)
$(LOCALDIRS):
	$(MAKE) -C $(@:local-%=%) local

clean: $(CLEANDIRS)
$(CLEANDIRS):
	$(MAKE) -C $(@:clean-%=%) clean

.PHONY: subdirs $(DIRS)
.PHONY: subdirs $(BUILDDIRS)
.PHONY: subdirs $(INSTALLDIRS)
.PHONY: subdirs $(SYSINSTALLDIRS)
.PHONY: subdirs $(TESTDIRS)
.PHONY: subdirs $(CLEANDIRS)
.PHONY: all install clean local sysinstall
