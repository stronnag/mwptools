APP=replay_bbox_ltm.rb
DEP=inav_states.rb
include ../common.mk
all:

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP) $(DEP)
	install -d $(prefix)/bin
	install -m 755 $(APP) $(prefix)/bin/$(APP)
	install $(DEP) $(prefix)/bin/$(DEP)

.PHONY: all clean local install
