
prefix ?= $$HOME/.local
APP = movemission

$(APP):	$(wildcard *.go)
	-go build -trimpath -ldflags "-w -s" -o $(APP)

clean:
	go clean
	rm -f $(APP)

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
