prefix ?= $(HOME)/.local

APP = play-ltm
SRC = ltm.go  ltm-player.go go.mod

$(APP) : $(SRC)
	go build  -o $(APP) -ldflags "-w -s"

install : $(APP)
	install -d $(prefix)/bin
	install $(APP) $(prefix)/bin/

clean:
	rm -f $(APP)
