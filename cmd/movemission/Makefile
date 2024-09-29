
prefix ?= $$HOME/.local
APP = movemission

$(APP):	$(wildcard *.go)
	-go build -trimpath -ldflags "-w -s"

clean:
	go clean
	rm -f $(APP) $(APP).exe *~

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
