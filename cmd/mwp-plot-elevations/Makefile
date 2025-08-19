prefix ?= $$HOME/.local

APP = mwp-plot-elevations

$(APP):	$(wildcard *.go)
	-go build -trimpath -ldflags "-w -s" -o $(APP)

clean:
	go clean
	rm -f $(APP)

local:
	$(MAKE) prefix=$(prefix) datadir=$(prefix)/ install

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)
