APP=replay_bbox_ltm.rb
include ../common.mk
all:

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	install -m 755 -D $(APP) $(prefix)/bin/$(APP)

.PHONY: all clean local install
