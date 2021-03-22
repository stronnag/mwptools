-include ../local.mk
-include local.mk
include ../common.mk

APP = otxlog

$(APP):	$(wildcard *.go)
	-go build -ldflags "-w -s"

clean:
	go clean

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
