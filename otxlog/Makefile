-include ../local.mk
-include local.mk
include ../common.mk

APP = otxlog

$(APP):	$(wildcard *.go)
	-go build -ldflags "-w -s"

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
