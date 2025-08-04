include vala.mk

HOME ?=$$HOME

SPKG=--pkg sqlite3 --pkg gio-2.0

COPTS=-X -O3 -X -s -X -lm

mwp-sql-rebase: mwp-sql-rebase.vala mwp-rebase.vala geocalc.vala
	valac $(OPTS) $(COPTS) $(SPKG)  $^ -o $@


clean:
	rm -rf mwp-sql-rebase *~
