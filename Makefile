DIRS = mspsim pidedit switchedit common/ublox-test cf-cli horizon mwp
INSTALLDIRS = $(DIRS:%=install-%)
SYSINSTALLDIRS = $(DIRS:%=sys-install-%)
CLEANDIRS = $(DIRS:%=clean-%)

all: $(DIRS)
$(DIRS):
	$(MAKE) -C $@

install: $(INSTALLDIRS)
$(INSTALLDIRS):
	$(MAKE) -C $(@:install-%=%) install-local

sysinstall: $(SYSINSTALLDIRS)
$(SYSINSTALLDIRS):
	$(MAKE) -C $(@:sysinstall-%=%) install-system


clean: $(CLEANDIRS)
$(CLEANDIRS):
	$(MAKE) -C $(@:clean-%=%) clean

.PHONY: subdirs $(DIRS)
.PHONY: subdirs $(BUILDDIRS)
.PHONY: subdirs $(INSTALLDIRS)
.PHONY: subdirs $(TESTDIRS)
.PHONY: subdirs $(CLEANDIRS)
.PHONY: all install clean sysinstall
