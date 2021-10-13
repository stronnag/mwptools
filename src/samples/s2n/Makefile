EXES = ser2udp

all: $(EXES)

ser2udp: ser2udp.go get_interface_other.go
	go build -ldflags "-w -s" -o $@

ser2udp.exe: ser2udp.go get_interface_windows.go
	GOOS=windows go build -ldflags "-w -s" -o $@

linux:
	GOOS=linux go build -ldflags "-w -s" -o ser2udp.$@

freebsd:
	GOOS=freebsd go build -ldflags "-w -s" -o ser2udp.$@

windows: ser2udp.exe

clean:
	rm -f ser2udp ser2udp.exe ser2udp.linux ser2udp.freebsd
