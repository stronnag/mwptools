APP=replay_bbox_ltm.rb
include ../common.mk
all:

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	install -d $(prefix)/bin
	install -m 755 $(APP) $(prefix)/bin/$(APP)

.PHONY: all clean local install
