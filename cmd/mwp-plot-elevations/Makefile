-include ../local.mk
-include local.mk
include ../common.mk

APP = mwp-plot-elevations

$(APP):	$(wildcard *.go)
	-go build -trimpath -ldflags "-w -s" -o $(APP)

clean:
	go clean
	rm -f $(APP)

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
