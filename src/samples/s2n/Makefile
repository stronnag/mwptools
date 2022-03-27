EXE = ser2udp
prefix ?= /usr/local

all: $(EXE)

ser2udp: ser2udp.go get_interface_other.go go.sum
	go build -ldflags "-w -s" -o $@

ser2udp.exe: ser2udp.go get_interface_windows.go go.sum
	GOOS=windows go build -ldflags "-w -s" -o $@

linux:	ser2udp.go get_interface_other.go go.sum
	GOOS=linux go build -ldflags "-w -s" -o ser2udp.$@

freebsd: ser2udp.go get_interface_other.go go.sum
	GOOS=freebsd go build -ldflags "-w -s" -o ser2udp.$@

windows: ser2udp.exe

go.sum: go.mod
	go mod tidy

clean:
	rm -f ser2udp ser2udp.exe ser2udp.linux ser2udp.freebsd

install: $(EXE)
	-install -d $(prefix)/bin
	-install -s $(EXE) $(prefix)/bin/
