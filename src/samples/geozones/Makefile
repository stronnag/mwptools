APP=geozones

all: $(APP)

prefix ?= $$HOME/.local

go.sum: go.mod
	go mod tidy

$(APP): $(wildcard *.go) go.sum
	go build -ldflags "-s -w"

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/

clean:
	rm -f $(APP) *~
