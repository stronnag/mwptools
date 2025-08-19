prefix ?= $$HOME/.local

APP = wintz

$(APP): main.go go.sum
	go build -ldflags "-w -s"

go.sum: go.mod
	go mod tidy

clean:
	rm -f wintz wintz.exe go.sum

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
