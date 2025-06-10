EXE = mspmplex
prefix ?= $$HOME/.local

all: $(EXE)

mspmplex: main.go mspparser.go get_interface_other.go go.sum
	go build -ldflags "-w -s" -o $@

mspmplex.exe: main.go mspparser.go get_interface_windows.go go.sum
	GOOS=windows go build -ldflags "-w -s" -o $@

linux:	main.go mspparser.go get_interface_other.go go.sum
	GOOS=linux go build -ldflags "-w -s" -o mspmplex.$@

freebsd: main.go mspparser.go get_interface_other.go go.sum
	GOOS=freebsd go build -ldflags "-w -s" -o mspmplex.$@

windows: mspmplex.exe

go.sum: go.mod
	go mod tidy

clean:
	rm -f mspmplex mspmplex.exe mspmplex.linux mspmplex.freebsd go.sum

install: $(EXE)
	-install -d $(prefix)/bin
	-install -s $(EXE) $(prefix)/bin/
