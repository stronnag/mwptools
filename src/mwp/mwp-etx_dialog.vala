/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

namespace ETX {
	uint selidx;
	bool speedup;
	uint duras;

	private File? etxfile;
	private GLib.ListStore lstore;
	ETX.Window etx;

	public class ETXEntry : Object {
		public int idx  {get; construct set;}
		public string duration  {get; construct set;}
		public string timestamp  {get; construct set;}
		public int lines  {get; construct set;}
		public bool issel  {get; construct set;}

		public ETXEntry(int idx, string duration, string timestamp, int lines) {
			Object(idx: idx, duration: duration, timestamp: timestamp,
				   lines: lines, issel: false);
		}
	}

	public void replay_etx(string? s) {
		etx = new ETX.Window();
		etx.complete.connect(() => {
				Mwp.run_replay(etxfile.get_path(), !speedup, Mwp.Player.OTX, (int)selidx+1, 0, 0, duras);
			});
		etx.run(s);
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/etx_dialog.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		private unowned Gtk.Button log_btn;
		[GtkChild]
		private unowned Gtk.Label log_name;
		[GtkChild]
		private unowned Gtk.CheckButton speedup;
		[GtkChild]
		private unowned Gtk.ColumnView etxlist;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn index;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn duration;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn timestamp;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn lines;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn cb;
		[GtkChild]
		private unowned Gtk.Button cancel;
		[GtkChild]
		private unowned Gtk.Button apply;

		public signal void complete();

		private void setup_factories() {
			lstore = new GLib.ListStore(typeof(ETXEntry));
			var f0 = new Gtk.SignalListItemFactory();
			index.set_factory(f0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as ETXEntry;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.idx.to_string());
				});
			var f1 = new Gtk.SignalListItemFactory();
			duration.set_factory(f1);
			f1.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f1.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as ETXEntry;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.duration);
				});

			var f2 = new Gtk.SignalListItemFactory();
			timestamp.set_factory(f2);
			f2.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f2.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as ETXEntry;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.timestamp);
				});

			var f3 = new Gtk.SignalListItemFactory();
			lines.set_factory(f3);
			f3.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f3.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as ETXEntry;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.lines.to_string());
				});

			var f4 = new Gtk.SignalListItemFactory();
			cb.set_factory(f4);
			f4.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var cbb = new Gtk.Label("");
					list_item.set_child(cbb);
				});
			f4.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as ETXEntry;
					var ccb = list_item.get_child() as Gtk.Label;
					ccb.label = (mi.issel) ? "✔" : "";
					mi.notify["issel"].connect((s,p) => {
							ccb.label = (((ETXEntry)s).issel) ? "✔" : "";
						});
				});

			var model = new Gtk.SingleSelection(lstore);
			etxlist.set_model(model);
			etxlist.set_single_click_activate(true);
			etxlist.activate.connect((n) => {
					selidx = n;
					apply.sensitive = true;
					for(var j = 0; j < lstore.n_items; j++) {
						((ETXEntry)lstore.get_item(j)).issel = (j == n);
					}
				});
		}

		public Window() {
			transient_for = Mwp.window;
			apply.sensitive = false;
			ETX.speedup = false;
			ETX.selidx = 0;

			setup_factories();

			apply.clicked.connect( (id) => {
					Mwp.add_toast_text("Preparing log for replay ... ");								ETX.speedup = this.speedup.active;
					var o = lstore.get_item(selidx) as ETXEntry;
					if (o != null) {
						var parts = o.duration.split(";");
						ETX.duras = (parts.length == 2) ? (uint)int.parse(parts[0])*60 + (uint)(double.parse(parts[1])+0.5) : 0;
					}
					complete();
					close();
				});
			cancel.clicked.connect(() => {
					close();
				});

			log_btn.clicked.connect(() => {
					IChooser.Filter []ifm = {
						{"ETX", {"csv"}},
					};
					var fc = IChooser.chooser(Mwp.conf.logpath, ifm);
					fc.title = "Open ETX/OTX File";
					fc.modal = true;
					fc.open.begin (Mwp.window, null, (o,r) => {
							try {
								var file = fc.open.end(r);
								etxfile = file;
								log_name.label = file.get_basename();
								get_etx_metas();
							} catch (Error e) {
								MWPLog.message("Failed to open ETX file: %s\n", e.message);
							}
						});
				});
		}

		public void run(string? s=null) {
			if(s != null) {
				etxfile = File.new_for_path(s);
				log_name.label = etxfile.get_basename();
				get_etx_metas();
			}
			present();
		}

		private async bool meta_reader(DataInputStream inp)  throws Error {
			for(;;) {
				try {
					var line = yield inp.read_line_async();
					if (line == null) {
						break;
					} else {
						var parts = line.split(",");
						if (parts.length == 7) {
							int flags = int.parse(parts[5]);
							if (flags != 0) {
								int idx = int.parse(parts[0]);
								int istart = int.parse(parts[3]);
								int iend= int.parse(parts[4]);
								int dura= int.parse(parts[5]);
								var dtext="%02d:%02d".printf(dura/60, dura%60);
								var b = new ETXEntry(idx, dtext, parts[2], iend-istart+1);
								lstore.append(b);
							}
						}
					}
				} catch (Error e) {
					return false;
				}
			}
			return true;
		}

		private void get_etx_metas() {
			try {
				var subp = new Subprocess(SubprocessFlags.STDOUT_PIPE, "fl2ltm", "--metas", etxfile.get_path());
				var dis = new DataInputStream(subp.get_stdout_pipe());
				meta_reader.begin(dis, (obj,res) => {
						try {
							meta_reader.end(res);
						} catch {};
					});
				var pid = subp.get_identifier();
				if(pid != null) {
					subp.wait_check_async.begin(null, (obj,res) => {
							try {
								subp.wait_check_async.end(res);
							} catch {}
						});
				}
			} catch (Error e) {}
		}
	}
}
