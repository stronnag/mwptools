include ../common.mk

local: $(APPS)
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APPS)
	install -d $(prefix)/bin
	install plot-elevations.rb $(prefix)/bin/mwp-plot-elevations.rb

.PHONY: clean
