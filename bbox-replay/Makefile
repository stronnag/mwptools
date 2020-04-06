APP=replay_bbox_ltm.rb
DEP=inav_states.rb
include ../common.mk


local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP) $(DEP)
	install -d $(prefix)/bin
	install -m 755 $(APP) $(prefix)/bin/$(APP)
	install -m 644 $(DEP) $(prefix)/bin/$(DEP)
	$(MAKE) -C bbsummary install

BBS:
	$(MAKE) -C bbsummary

.PHONY: clean local install
.PHONY: BBS
