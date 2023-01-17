prefix ?= $$HOME/.local
APPS = clitest msptest

all: $(APPS)

clitest: clitest.go cliser.go go.sum
	-go build -ldflags "-w -s" -o clitest clitest.go cliser.go

msptest: msptest.go mspser.go go.sum
	-go build -ldflags "-w -s" -o msptest msptest.go mspser.go

go.sum: go.mod
	go mod tidy

clean:
	go clean

install: $(APPS)
	-install -d $(prefix)/bin
	-install -s $(APPS) $(prefix)/bin/
