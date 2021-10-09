EXES = ser2udp ser2udp.exe

all: $(EXES)

ser2udp: ser2udp.go
	GOOS=linux go build -ldflags "-w -s" -o $@

ser2udp.exe: ser2udp.go
	GOOS=windows go build -ldflags "-w -s" -o $@

clean:
	rm -f ser2udp ser2udp.exe
