prefix ?= $(HOME)/.local
APP = mwp-serial-cap
GOFILES = btaddr_linux.go  btaddr_other.go ti_simple.go

$(APP):  $(APP).go $(GOFILES)
	go build -ldflags "-w -s"

install: $(APP)
	install -d $(prefix)/bin
	install $(APP) $(prefix)/bin/

clean:
	rm -f $(APP) $(APP).exe
