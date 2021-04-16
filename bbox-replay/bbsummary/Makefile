-include ../../local.mk
-include local.mk
include ../../common.mk

APP = bbsummary

APP:
	go build -trimpath -ldflags "-w -s"

install: $(APP)
	install -d $(prefix)/bin
	install -s $(APP) $(prefix)/bin/$(APP)
