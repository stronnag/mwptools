APP = caltool
prefix ?= /usr/local

$(APP):	$(wildcard *.go)
	-go build -o $(APP) -ldflags "-w -s"

clean:
	go clean

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
