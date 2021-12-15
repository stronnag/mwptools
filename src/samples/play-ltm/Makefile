prefix ?= $(HOME)/.local

APP = play-ltm
SRC = ltm.go  ltm-player.go go.mod go.sum

$(APP) : $(SRC)
	go build  -o $(APP) -ldflags "-w -s"

go.sum : go.mod
	go mod tidy

install : $(APP)
	install -d $(prefix)/bin
	install $(APP) $(prefix)/bin/

clean:
	rm -f $(APP)
