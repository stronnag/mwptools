prefix ?= $$HOME/.local
APPS = cli-set-test msp-set-test

all: $(APPS)

cli-set-test: clitest.go cliser.go go.sum
	-go build -ldflags "-w -s" -o cli-set-test clitest.go cliser.go

msp-set-test: msptest.go mspser.go go.sum
	-go build -ldflags "-w -s" -o msp-set-test msptest.go mspser.go

go.sum: go.mod
	go mod tidy

clean:
	go clean

install: $(APPS)
	-install -d $(prefix)/bin
	-install -s $(APPS) $(prefix)/bin/
