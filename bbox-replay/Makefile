APP0=replay_bbox_ltm.rb
APP1=inav_states.rb
DEP=inav_states_data.rb
include ../common.mk

.PHONY: clean local install
.PHONY: BBS all
.SILENT: all

all:

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP) $(DEP)
	install -d $(prefix)/bin
	install -m 755 $(APP0) $(prefix)/bin/$(APP)
	install -m 755 $(APP1) $(prefix)/bin/$(APP)
	install -m 644 $(DEP) $(prefix)/bin/$(DEP)

BBS:
	$(MAKE) -C bbsummary
