prefix ?= $(HOME)/.local
APP = mwp-serial-cap
GOFILES = btaddr_linux.go  btaddr_other.go ti_simple.go

$(APP):  $(APP).go $(GOFILES) go.sum
	go build -o $@ -ldflags "-w -s"

go.sum: go.mod
	go mod tidy

install: $(APP)
	install -d $(prefix)/bin
	install $(APP) $(prefix)/bin/

clean:
	rm -f $(APP)
