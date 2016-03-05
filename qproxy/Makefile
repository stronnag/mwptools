SRC=
ifdef QPROXY
SRC=qproxy
else
SRC=genproxy
endif
APP=qproxy

# This is unadulated evil, and it's all Ubuntu LTS's fault

$(APP): $(SRC).vala
	valac --pkg libsoup-2.4 --pkg posix -o $(APP) $(SRC).vala
clean:
	rm -f qproxy *~ *.vala.c

local:
	$(MAKE) prefix=$(HOME) datadir=$(HOME)/.local install

install: $(APP)
	install -sD $(APP) $(prefix)/bin/$(APP)
