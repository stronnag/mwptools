APP = mwplogstats
prefix ?= $$HOME/.local

$(APP):	$(wildcard *.go) go.sum
	-go build -ldflags "-w -s"

go.sum: go.mod
	go mod tidy

clean:
	go clean
	rm -f $(APP) $(APP).exe

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
