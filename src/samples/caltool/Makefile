APP = caltool
prefix ?= /usr/local

$(APP):	$(wildcard *.go) go.sum
	-go build -o $(APP) -ldflags "-w -s"

go.sum: go.mod
	go mod tidy

clean:
	go clean

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
