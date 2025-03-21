namespace Mwpset {
	const int RROW=3;
	const int VROW=4;
	private string simple_wrap(string s) {
		const int WRAP_POS = 84;
		int [] sls = {};
		int ls = 0;
		int k = 0;
		int j = 0;
		unichar c;
		var sb = new StringBuilder();
		if(s.length < WRAP_POS) {
			return s;
		}

		while(s.get_next_char(ref j, out  c)) {
			if(c.isspace()) {
				ls = j;
			}
			if (k > WRAP_POS) {
				k = 0;
				sls += ls;
			}
			k++;
		}
		sls += -1;
		k = 0;
		j = 0;
		while(s.get_next_char(ref j, out c)) {
			if(j == sls[k]) {
				sb.append_c('\n');
				k++;
			} else {
				sb.append_unichar(c);
			}
		}
		return sb.str;
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/mwpsetedit.ui")]
	public class EditWindow : Adw.Window {
		[GtkChild]
		private unowned Gtk.Grid setgrid;
		[GtkChild]
		private unowned Gtk.Label sumtext;
		[GtkChild]
		private unowned	Gtk.Label desctext;
		[GtkChild]
		private unowned	Gtk.Label deftext;
		[GtkChild]
		private unowned Gtk.Button usedef;
		[GtkChild]
		private unowned	Gtk.Button appset;

		public signal void changed(string s);

		private Mwpset.Window _pw;

		public EditWindow(Mwpset.Window pw) {
			_pw = pw;
			transient_for = pw;
			this.default_width = pw.default_width -  80;
		}

		public void run(XReader.KeyEntry k) {
			bool have_range = false;
			title = k.name;
			sumtext.label = k.summary;
			var dtxt = k.description;
			if(Gtk.get_major_version() >=  4 && Gtk.get_minor_version() >=  18) {
				desctext.label = dtxt;
				desctext.wrap = true;
			} else {
				desctext.label = simple_wrap(dtxt);
			}
			desctext.set_use_markup(true);
			var dv = XReader.normalise(k._default);
			deftext.label = dv;

			if(k._enum != null) {
				int i = 0;
				int j = 0;
				var rs = k.value.get_string();
				string []evstrs = {};
				foreach (var ei in k._enum.eset.data) {
					if (ei.k == rs) {
						j = i;
					}
					evstrs += ei.k;
					i++;
				}
				var dd =  new Gtk.DropDown.from_strings(evstrs);
				dd.selected = j;
				setgrid.attach (dd, 1, VROW);

			} else if (k.choices != null) {
				var dd =  new Gtk.DropDown.from_strings(k.choices.data);
				int i = 0;
				int j = 0;
				var rs = k.value.print(false);
				foreach (var ci  in k.choices.data) {
					if (ci == rs) {
						i = j;
					}
					j++;
				}
				dd.selected = i;
				setgrid.attach (dd, 1, VROW);
			} else {
				var o = new Gtk.Entry();
				var rs = XReader.format_variant(k);
				o.buffer.set_text(rs.data);
				setgrid.attach (o, 1, VROW);
				o.activate.connect(() => {
						if(have_range) {
							check_range(k, o);
						}
					});
			}

			StringBuilder sb = new StringBuilder("");
			if(k.min != null) {
				sb.append_printf("Minimum: %s ", k.min);
			}
			if(k.max != null) {
				sb.append_printf("Maximum: %s ", k.max);
			}
			if(sb.str.length > 0) {
				have_range = true;
				var l1 = new Gtk.Label(sb.str);
				l1.xalign = 0;
				setgrid.attach (l1, 1, RROW);
				var l0 = new Gtk.Label("<b>Range:</b>");
				l0.use_markup = true;
				l0.xalign = 0;
				setgrid.attach (l0, 0, RROW);
			} else if(k.type == "as") {
				var l0 = new Gtk.Label("<b>Array format:</b>");
				l0.use_markup = true;
				l0.xalign = 0;
				setgrid.attach (l0, 0, RROW);
				var l1 = new Gtk.Label( "<b><tt>['item1','item2','itemN']</tt></b>. Brackets, commas, quotes are required. <b><tt>[]</tt></b> denotes empty array");
				l1.xalign = 0;
				l1.use_markup = true;
				l1.wrap = true;
				setgrid.attach (l1, 1, RROW);
			}

			appset.clicked.connect(() => {
					if(k._enum != null || k.choices != null) {
						var dd = setgrid.get_child_at(1, VROW) as Gtk.DropDown;
						var i = dd.selected;
						var c = ((Gtk.StringList)dd.model).get_string(i);
						//var rs = k.value.get_string();
						string rs = XReader.format_variant(k);
						if(rs != c) {
							changed(c);
						};
						close();
					} else {
						bool ok = true;
						var o = setgrid.get_child_at(1, VROW) as Gtk.Entry;
						if(have_range) {
							ok = check_range(k, o);
						}
						if (ok) {
							var str = o.text;
							string rs = XReader.format_variant(k);
							if(str != rs) {
								changed(str);
							};
							close();
						}
					}
				});

			usedef.clicked.connect(() => {
					if(k._enum != null) {
						var dd = setgrid.get_child_at(1, VROW) as Gtk.DropDown;
						int i = 0;
						int j = 0;
						var kdv = XReader.normalise(k._default); // FIXME
						foreach (var ei in k._enum.eset.data) {
							if (ei.k == kdv) {
								i = j;
								break;
							}
							j++;
						}
						dd.selected = i;
					} else if (k.choices != null) {
						var dd = setgrid.get_child_at(1, VROW) as Gtk.DropDown;
						int i = 0;
						int j = 0;
						var s = XReader.normalise(k._default);
						foreach (var ci  in k.choices.data) {
							if (ci == s) {
								i = j;
							}
							j++;
						}
						dd.selected = i;
					} else {
						var o = setgrid.get_child_at(1, VROW) as Gtk.Entry;
						var s = XReader.normalise(k._default);
						o.buffer.set_text(s.data);
					}
				});

			present();
		}

		bool check_range(XReader.KeyEntry k, Gtk.Entry e) {
			bool ok = true;
			var ival = int.parse(e.text);
			if(k.min != null) {
				var mval = int.parse(k.min);
				if(ival < mval) {
					e.text = XReader.format_variant(k);
					ok = false;
				}
			}
			if(ok && k.max != null) {
				var mval = int.parse(k.max);
				if(ival > mval) {
					e.text = XReader.format_variant(k);
					ok = false;
				}
			}
			if(!ok) {
				_pw.add_toast_text("Value %d is out of range".printf(ival));
			}
			return ok;
		}
	}
}
