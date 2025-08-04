include vala.mk

APP = mwp-sql-rebase
prefix ?= $$HOME/.local

SPKG=--pkg sqlite3 --pkg gio-2.0

COPTS=-X -O3 -X -s -X -lm

mwp-sql-rebase: mwp-sql-rebase.vala mwp-rebase.vala geocalc.vala
	valac $(OPTS) $(COPTS) $(SPKG)  $^ -o $@

install: $(APP)
	-install -d $(prefix)/bin
	-install -s $(APP) $(prefix)/bin/$(APP)

clean:
	rm -rf mwp-sql-rebase *~
