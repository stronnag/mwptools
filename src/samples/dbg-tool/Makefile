-include ../../local.mk
-include local.mk
-include ../../common.mk

APP = dbg-tool

$(APP):	$(wildcard *.go)
	-go build -ldflags "-w -s"

clean:
	go clean

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
