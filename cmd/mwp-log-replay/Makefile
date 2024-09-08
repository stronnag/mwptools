prefix ?= $(HOME)/.local
APP = mwp-log-replay
GOFILES = btaddr_linux.go btaddr_other.go

$(APP):  $(APP).go $(GOFILES)
	go build -ldflags "-w -s"

install: $(APP)
	install -d $(prefix)/bin
	install $(APP) $(prefix)/bin/

clean:
	rm -f $(APP) $(APP).exe
