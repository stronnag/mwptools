VALAC=valac
OPTS=-X -O2 -X -lm

frsky: frsky.vala
	$(VALAC) $(OPTS) --pkg gio-2.0  $<

clean:
	rm -f frsky
