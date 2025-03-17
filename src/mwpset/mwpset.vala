using Gtk;

namespace Mwpset {
	string schm;

	[GtkTemplate (ui = "/org/stronnag/mwp/mwpsetting.ui")]
	public class Window : Adw.ApplicationWindow {
		private const ActionEntry[] ACTION_ENTRIES = {
			{ "backup", do_backup },
			{ "restore", do_restore },
			{ "quit", do_quit },
		};

		[GtkChild]
		private unowned Adw.ToastOverlay toaster;
		[GtkChild]
		private unowned Gtk.ListBox lbox;
		[GtkChild]
		private unowned Gtk.ScrolledWindow sw;
		[GtkChild]
		private unowned  Gtk.Button savelist;

		private XReader x;

		public void add_toast_text(string s) {
			var t = new Adw.Toast(s);
			toaster.add_toast(t);
        }

		public Window() {
			title = schm;
			add_action_entries (ACTION_ENTRIES, this);
			x = new XReader(schm);
			x.parse_schema();

			savelist.clicked.connect(() => {
					for(int i = 0; i < x.keys.length; i++) {
						if(x.keys.data[i].is_changed) {
							x.settings.set_value(x.keys.data[i].name, x.keys.data[i].value);
							var w = find_value_labels(i, x.keys.data[i].name) as Gtk.Label;
							if (w != null) {
								w.remove_css_class("error");
								w = ((Gtk.Widget)w).get_next_sibling() as Gtk.Label;
								w.remove_css_class("error");
							}
						}
					}
				});

			for(int i = 0; i < x.keys.length; i++) {
				add_row(i);
			}
			sw.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
			sw.propagate_natural_height = true;
			sw.propagate_natural_width = true;

			lbox.row_activated.connect((l) => {
					int i = l.get_index();
					run_edit(i);
				});
		}

		private void do_backup() {
			IChooser.Filter []ifm = {{"Settings Ini", {"ini"}},};
			var dc = Environment.get_user_special_dir(UserDirectory.DOCUMENTS);
			var fc = IChooser.chooser(dc, ifm);
			fc.title = "Save Settings Ini File";
			fc.modal = true;
			fc.save.begin (this, null, (o,r) => {
					try {
						var fh = fc.save.end(r);
						var fn = fh.get_path ();
						var fs = FileStream.open(fn, "w");
						if (fs != null) {
							fs.puts("[mwp]\n");
							for(int i = 0; i < x.keys.length; i++) {
								var rs = x.keys.data[i].value.print(false);
								fs.printf("%s=%s\n", x.keys.data[i].name, rs);
							}
						}
					} catch (Error e) {
						var estr = "Failed to save file: %s".printf(e.message);
						stderr.printf("%s\n", estr);
						add_toast_text(estr);
					}
				});
		}

		private void do_restore(){
			IChooser.Filter []ifm = {{"Settings Ini", {"ini"}},};
			var dc = Environment.get_user_special_dir(UserDirectory.DOCUMENTS);
			var fc = IChooser.chooser(dc, ifm);
			fc.title = "Restore Settings Ini File";
			fc.modal = true;
			fc.open.begin (this, null, (o,r) => {
					try {
						var file = fc.open.end(r);
						var fn = file.get_path ();
						var fs = FileStream.open(fn, "r");
						if (fs != null) {
							string? line;
							while((line = fs.read_line()) != null) {
								line = line.chomp();
								if(line.has_prefix("[")) {
									continue;
								}
								var parts=line.split("=");
								if (parts.length == 2) {
									uint idx = 0;
									var ok = x.keys.find_custom(parts[0], (ArraySearchFunc)XReader.k_search, out idx);
									if (ok) {
										string rs = x.keys.data[idx].value.print(false);
										if (rs != parts[1]) {
											var disp = XReader.format_variant(x.keys.data[idx]);
											if(x.keys.data[idx].type == "d") {
												var dbl = DStr.strtod(parts[1], null);
												disp = "%.8g".printf(dbl);
											}
											update_row((int)idx, parts[0], disp);
											if(x.keys.data[idx].type == null) {
												x.keys.data[idx].value = new Variant.string(parts[1]);
											} else {
												var ty = new VariantType(x.keys.data[idx].type);
												x.keys.data[idx].value = Variant.parse(ty, parts[1]);
											}
											x.keys.data[idx].is_changed = true;
										}
									}
								}
							}
						}
					} catch (Error e) {
						var estr = "Failed to open settings file: %s".printf(e.message);
						stderr.printf("%s\n", estr);
						add_toast_text(estr);
					}
				});;
		}

		private unowned Gtk.Widget find_value_labels(int n, string name) {
			unowned Gtk.Widget? child = null;
			var lr = lbox.get_row_at_index(n);
			if(lr != null) {
				child = lr.get_first_child();
				if(child != null) {
					child = child.get_first_child();
					if(child != null) {
						child = child.get_next_sibling();
						var sname = ((Gtk.Label)child).label;
						if(name == sname) {
							return child;
						}
					}
				}
			}
			return child;
		}

		private void update_row(int n, string name, string nvalue) {
			var w = find_value_labels(n, name) as Gtk.Label;
			if (w != null) {
				w.add_css_class("error");
				w = ((Gtk.Widget)w).get_next_sibling() as Gtk.Label;
				w.label = nvalue;
				w.add_css_class("error");
			}
		}

		private void do_quit() {
			close();
		}

		public void add_row(int i) {
			var lb = new Gtk.ListBoxRow();
			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
			var btn = new Gtk.Button.from_icon_name("document-edit");
			var sname = new Gtk.Label(x.keys.data[i].name);
			string rs = XReader.format_variant(x.keys.data[i]);

			var sval = new Gtk.Label(rs);

			btn.halign = Gtk.Align.START;
			btn.clicked.connect(() => {
					run_edit(i);
				});

			box.append(btn);
			sname.halign = Gtk.Align.START;
			sname.hexpand = true;
			box.append(sname);

			sval.halign = Gtk.Align.END;

			box.append(sval);
			lb.set_child(box);
			lbox.append(lb);
		}

		private void run_edit(int i) {
			var ew = new EditWindow(this);
			ew.changed.connect((s) => {
					update_row(i, x.keys.data[i].name, s);
					set_value_from_string(i, s);
					x.keys.data[i].is_changed = true;
				});
			ew.close_request.connect(() => {
					return false;
				});
			ew.run(x.keys.data[i]);
		}

		private void set_value_from_string(int i, string s) {
			if(x.keys.data[i].type == null || x.keys.data[i].type == "s") {
				x.keys.data[i].value = new Variant.string(s);
			} else if (x.keys.data[i].type == "d") {
				double d = DStr.strtod(s, null);
				x.keys.data[i].value = new Variant.double(d);
			} else {
				var ty = new VariantType(x.keys.data[i].type);
				try {
					x.keys.data[i].value = Variant.parse(ty, s);
				} catch (Error e) {
					var str = "Parse Error %s : %s".printf(s, e.message);
					add_toast_text(str);
					stderr.printf("%s\n", str);
				}
			}
		}
	}

	class App : Adw.Application {
		public App() {
			Object(application_id: "org.stronnag.mwpset",
				   flags: ApplicationFlags.FLAGS_NONE);
		}

		public override void activate () {
			var wdw = new Mwpset.Window();
			wdw.set_application (this);
			wdw.present();
		}

		public static int main(string?[] args) {
			if(Environment.get_variable("GSK_RENDERER") == null) {
				if (Environment.get_variable("LOCALAPPDATA") != null) { // Windows test
					Environment.set_variable("GSK_RENDERER", "cairo" ,true);
				}
			}
			print("mwpset %s\n", MWPSET_VERSION_STRING);
			if(args.length > 1) {
				Mwpset.schm = args[1];
			} else {
				Mwpset.schm = "org.stronnag.mwp";
			}
			var app = new App();
			app.run();
			return 0;
		}
	}
}
