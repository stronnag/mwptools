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

namespace BBLError {
	bool warn;
	string []lines;
}

namespace BBL {
	BBL.Window bbl;
	MapUtils.BoundingBox bbox;
	Utils.Warning_box wb;

	public void replay_bbl(string? s) {
		bbl = new BBL.Window();
		bbl.complete.connect(() => {
				bbl.find_bbox_box(BBL.bblname.get_path(), BBL.selidx+1);
			});

		bbl.rescale.connect((b) => {
				var z= MapUtils.evince_zoom(bbox);
				MapUtils.centre_on(bbox.get_centre_latitude(), bbox.get_centre_longitude(), z);
				if(videofile != null && videofile != "") {
					MWPLog.message("BBL videofile %s offset=%d\n", videofile, nsecs);
				}
				if(speedup) {
					videofile = null;
					vactive = false;
				}
				Mwp.run_replay(bblname.get_path(), !speedup, Mwp.Player.BBOX, (int)selidx+1, 0, 0, duras);
			});
		bbl.run(s);
	}

	public const int BB_MINSIZE = 4096;

	private File? bblname;
	bool is_valid ;
	bool is_broken;
	int []valid;
	string []orig_times;
	int maxidx;
	int nidx;
	uint selidx;
	bool speedup;
	uint duras;
	string videofile;
	bool vactive;
	int skiptime;
	int64 nsecs;

	GLib.ListStore lstore;

	public class BBLEntry : Object {
		public int idx  {get; construct set;}
		public string duration  {get; construct set;}
		public string timestamp  {get; construct set;}
		public bool issel  {get; construct set;}

		public BBLEntry(int idx, string duration, string timestamp) {
			this.idx =  idx;
			this.duration = duration;
			this.timestamp = timestamp;
			this.issel = false;
		}
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/bb_dialog.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		private unowned Gtk.Button log_btn;
		[GtkChild]
		private unowned Gtk.Label log_name;
		[GtkChild]
		private unowned Gtk.Label bb_items;
		[GtkChild]
		private unowned Gtk.DropDown tzoption;
		[GtkChild]
		private unowned Gtk.CheckButton speedup;
		[GtkChild]
		private unowned Gtk.ColumnView bblist;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn index;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn duration;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn timestamp;
		[GtkChild]
		private unowned Gtk.ColumnViewColumn cb;
		[GtkChild]
		private unowned Gtk.Button video_btn;
		[GtkChild]
		private unowned Gtk.Label video_name;
		[GtkChild]
		internal unowned Gtk.CheckButton vidbutton;
		[GtkChild]
		internal unowned Gtk.Entry min_entry;
		[GtkChild]
		internal unowned Gtk.Entry sec_entry;
		[GtkChild]
		internal unowned Gtk.Entry skip_entry;
		[GtkChild]
		private unowned Gtk.Button cancel;
		[GtkChild]
		private unowned Gtk.Button apply;

		public signal void complete();
		public signal void rescale();

		private void setup_factories() {
			lstore = new GLib.ListStore(typeof(BBLEntry));
			var f0 = new Gtk.SignalListItemFactory();
			index.set_factory(f0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as BBLEntry;
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
					var mi = list_item.get_item() as BBLEntry;
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
					var mi = list_item.get_item() as BBLEntry;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.timestamp);
					mi.notify["timestamp"].connect((s,p) => {
							label.set_text(mi.timestamp);
						});
				});
			var f3 = new Gtk.SignalListItemFactory();
			cb.set_factory(f3);
			f3.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var cbb = new Gtk.Label("");
					list_item.set_child(cbb);
				});
			f3.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as BBLEntry;
					var ccb = list_item.get_child() as Gtk.Label;
					ccb.label = (mi.issel) ? "✔" : "";
					mi.notify["issel"].connect((s,p) => {
							ccb.label = (((BBLEntry)s).issel) ? "✔" : "";
						});
				});

			var model = new Gtk.SingleSelection(lstore);
			bblist.set_model(model);
			bblist.set_single_click_activate(true);
			bblist.set_enable_rubberband(false);

			bblist.activate.connect((n) => {
					selidx = n;
					apply.sensitive = true;
					for(var j = 0; j < lstore.n_items; j++) {
						((BBLEntry)lstore.get_item(j)).issel = (j == n);
					}
				});
		}

		public Window() {
			transient_for = Mwp.window;
			apply.sensitive = false;
			BBL.videofile=null;
			BBL.speedup = false;

			BBL.is_valid = false;
			BBL.is_broken = false;
			BBL.valid = {};
			BBL.orig_times = {};
			BBL.maxidx = BBL.nidx = -1;
			BBL.selidx = 0;

			BBL.nsecs = 0;
			BBL.vactive = false;
			BBL.skiptime = 0;

			setup_factories();

			apply.clicked.connect( (id) => {
					Mwp.add_toast_text("Preparing log for replay ... ");
					BBL.speedup = this.speedup.active;
					BBL.vactive = vidbutton.active;
					BBL.skiptime = int.parse(skip_entry.text);
					if(BBL.vactive) {
						bool neg = false;
						var s = min_entry.text;
						if (s.has_prefix("-")) {
							neg = true;
						}
						var mins = (int.parse(min_entry.text)).abs();
						var secs = DStr.strtod(sec_entry.text);
						BBL.nsecs = (int64)((mins*60 + secs)*1e9);
						if(neg && BBL.nsecs > 0) { // for the '-0' case
							BBL.nsecs *= -1;
						}
					}
					var o = lstore.get_item(selidx) as BBLEntry;
					if (o != null) {
						var parts = o.duration.split(";");
						BBL.duras = (parts.length == 2) ? (uint)int.parse(parts[0])*60 + (uint)( DStr.strtod(parts[1])+0.5) : 0;
					}
					complete();
					close();
				});
			cancel.clicked.connect(() => {
					close();
				});

			tzoption.notify["selected"].connect(() => {
					var k = tzoption.selected;
					var ml = (Gtk.StringList)tzoption.model;
					var tstr = ml.get_string(k);
					int n;
					if(tz_exists(tstr, out n)) {
						update_time_stamps();
					}
				});

			log_btn.clicked.connect(() => {
					IChooser.Filter []ifm = {
						{"BBL", {"TXT", "bbl"}},
					};
					var fc = IChooser.chooser(Mwp.conf.logpath, ifm);
					fc.title = "Open BBL File";
					fc.modal = true;
					fc.open.begin (Mwp.window, null, (o,r) => {
							try {
								var file = fc.open.end(r);
								bblname = file;
								log_name.label = file.get_basename();
								get_bbox_file_status();
							} catch (Error e) {
								MWPLog.message("Failed to open BBL file: %s\n", e.message);
							}
						});
				});

			video_btn.clicked.connect(() => {
					IChooser.Filter []ifm = {
						{"Video", {"mp4", "webm","mkv"}},
					};
					var hd = Environment.get_home_dir();
					var vpath = Path.build_filename(hd, "Videos");
					var fc = IChooser.chooser(vpath, ifm);
					fc.title = "Open Video File";
					fc.modal = true;
					fc.open.begin (Mwp.window, null, (o,r) => {
							try {
								var file = fc.open.end(r);
								videofile = file.get_path ();
								video_name.label = file.get_basename();
							} catch (Error e) {
								MWPLog.message("Failed to open Video file: %s\n", e.message);
							}
						});
				});
		}

		public void run(string? s=null) {
			if(s != null) {
				bblname = File.new_for_path(s);
				log_name.label = bblname.get_basename();
				get_bbox_file_status();
			}
			present();
		}

		private void update_time_stamps() {
			for(var i = 0; i < lstore.get_n_items(); i++) {
				var be = lstore.get_item(i) as BBLEntry;
				if(be.timestamp != "Unknown"  && be.timestamp !=  "Invalid") {
					var nts = get_formatted_time_stamp(i);
					be.timestamp = nts;
				}
			}
		}

		private void get_bbox_file_status() {
			lstore.remove_all();
			tzoption.selected = 0;
			bb_items.label = "Analysing log ...";
			find_valid();
			apply.sensitive = false;
		}

		private bool tz_exists(string s, out int row_count) {
			int i,n = -1;
			var ml = (Gtk.StringList)tzoption.model;
			for(i = 0; i < ml.get_n_items(); i++) {
				if(s == ml.get_string(i)) {
					n = i;
					break;
				}
			}
			row_count = (n == -1) ? i : n;
			return (n != -1);
		}

		private int add_if_missing(string str, bool top=false) {
			int nrow = 0;
			if(!tz_exists(str, out nrow)) {
				var sl = new Gtk.StringList({});
				if(top) {
					sl.append(str);
				}
				var ml = (Gtk.StringList)tzoption.model;
				for(var i = 0; i < ml.get_n_items(); i++) {
					sl.append(ml.get_string(i));
				}
				if(!top){
					sl.append(str);
				}
				tzoption.model = sl;
				tzoption.selected = 0;
			}
			return nrow;
		}

		private void find_valid() {
			BBLError.warn = false;
			BBLError.lines = {};

			is_valid = false;
			is_broken = false;
			valid = {};
			maxidx = -1;
			var subp = new ProcessLauncher();
			var res = subp.run_argv({Mwp.conf.blackbox_decode, "--stdout", bblname.get_path()}, ProcessLaunch.STDERR);
			string line = null;
			//            string [] lines = {}; // for the error path
            size_t len = 0;
			if(res) {
				var errc = subp.get_stderr_iochan();
				errc.add_watch (IOCondition.IN|IOCondition.HUP, (src, cond) => {
						try {
							if (cond == IOCondition.HUP)
								return false;
							IOStatus eos = src.read_line (out line, out len, null);
							if(eos == IOStatus.EOF)
								return false;
							if(line == null || len == 0)
								return false;
							int idx=0, offset, size=0;
							if(line.scanf(" %d %d %d", &idx, &offset, &size) == 3) {
								if(size > BB_MINSIZE) {
									is_valid = true;
									valid += idx;
								}
								maxidx = idx;
							} else if(line.has_prefix("Log 1 of")) {
								valid += 1;
								maxidx = 1;
								is_valid = true;
								ProcessLauncher.kill(subp.get_pid());
								return false;
							}
							return true;
						} catch (Error e) {
							MWPLog.message("BBL reader: %s\n", e.message);
							return false;
						}
					});
				subp.complete.connect(() => {
						try {errc.shutdown(false);} catch {};
						if(!is_valid) {
							/*
							StringBuilder sb = new StringBuilder("No valid log detected.\n");
							if(lines.length > 0) {
								sb.append("blackbox_decode says: ");
								foreach(var l in lines) {
									sb.append(l.strip());
								}
							}
							*/
							set_normal("No valid log detected.\n");
						} else {
							var tsslen = find_start_times();
							spawn_decoder(0, tsslen);
						}
					});
			} else {
				MWPLog.message("Failed to run %s\n", Mwp.conf.blackbox_decode);
			}
		}

		private int find_start_times() {
			var n = 0;
			orig_times = {};
			bool first_ok = false;
			FileStream stream = FileStream.open (bblname.get_path(), "r");
			if (stream != null) {
				char buf[1024];
				while (stream.gets (buf) != null) {
					if(buf[0] == 'H' && buf[1] == ' ') {
						if(((string)buf).has_prefix("H Log start datetime:")) {
							int len = ((string)buf).length;
							buf[len-1] = 0;
							string ts = (string)buf[21:len-1];
							orig_times += ts;
							n++;
							if(first_ok == false && ts.has_prefix("20") && valid[n-1] != 0) {
								first_ok = true;
								process_tz_record(n);
							}
							if (n == maxidx)
								break;
						}
					}
				}
			}
			return n;
		}

		private void process_tz_record(int idx) {
			double xlat,xlon;
			if(find_base_position(bblname.get_path(), idx.to_string(), out xlat, out xlon)) {
				MapUtils.centre_on(xlat, xlon);
				get_tz(xlat, xlon);
			}
		}

		private void spawn_decoder(int j, int tsslen) {
			for(;j < maxidx && valid[j] == 0; j++)
				;
			if(j == maxidx) {
				set_normal("File contains %d %s".printf(maxidx, (maxidx == 1) ? "entry" : "entries"));
				if (BBLError.warn) {
					string title = "<b>Damaged Log</b>";
					StringBuilder sb = new StringBuilder();
					foreach(var l in BBLError.lines) {
						sb.append(l.chug());
					}
					sb.append("\nThe log may not replay correctly, if at all");
					var sw = new Gtk.ScrolledWindow();
					var l = new Gtk.TextView();
					l.create_buffer();
					l.buffer.set_text(sb.str);
					l.editable = false;
					int fw,fh;
					Utils.check_pango_size(l, "Sans", sb.str, out fw, out fh);
					fw += 4;
					fh += 4;
					if(fw > 600)
						fw = 600;
					if(fh > 480)
						fh = 480;
					l.width_request = fw;
					l.height_request = fh;
					sw.set_child(l);
					sw.propagate_natural_height = true;
					sw.propagate_natural_width = true;
					wb = new Utils.Warning_box(title, 0, this, sw);
					wb.present();
				}
				return;
			}
			nidx = j+1;
			var subp = new ProcessLauncher();
			var res = subp.run_argv({Mwp.conf.blackbox_decode, "--stdout", "--index", nidx.to_string(), bblname.get_path()}, ProcessLaunch.STDERR);
			if (res) {
				var errc = subp.get_stderr_iochan();
				errc.add_watch (IOCondition.IN|IOCondition.HUP, (src, cond) => {
						if (cond == IOCondition.HUP)
							return false;
						try {
							string line;
							size_t len = 0;
							IOStatus eos = src.read_line (out line, out len, null);
							if(eos == IOStatus.EOF)
								return false;
							if (line  == null || len == 0)
								return false;
							int n;
							n = line.index_of("Log ");
							if(n == 0) {
								n = line.index_of(" duration ");
								if(n > 16) {
									n += 10;
									string dura = line.substring(n, (long)len - n -1);
									string tsval;
									if(tsslen > 0 && maxidx == tsslen)
										tsval = get_formatted_time_stamp(j);
									else
										tsval = "Unknown";

									var b = new BBLEntry(nidx, dura, tsval);
									lstore.append(b);
								}
							} else if(line.has_prefix("WARNING:")) {
								if (BBLError.warn) {
									BBLError.lines += "\u200b\n"; //zero-width space to force NL
								}
								BBLError.lines += "NOTICE: Log segment #%d is damaged or ancient\n".printf(nidx);
								BBLError.warn = true;
							} else if (line.contains("Warning:") || line.contains("Error:")) {
								BBLError.lines += line;
								BBLError.warn = true;
							}
							return true;
						} catch (Error e) {
							MWPLog.message ("BBL reader: %s\n", e.message);
							return false;
						}
					});
				subp.complete.connect(() => {
						try { errc.shutdown(false); } catch {}
						ProcessLauncher.kill(subp.get_pid());
						spawn_decoder(j+1, tsslen);
					});
			} else {
				MWPLog.message("BBL failed to spawn\n");
			}
		}

		private void set_normal(string label) {
			bb_items.label = label;
		}

		private bool find_base_position(string filename, string index,
										out double xlat, out double xlon) {
			bool ok = false;
			xlon = xlat = 0;
			var subp = new ProcessLauncher();
			var res = subp.run_argv({Mwp.conf.blackbox_decode, "--stdout", "--index", index, "--merge-gps", filename}, ProcessLaunch.STDOUT);
			if (res) {
				var stdc = subp.get_stdout_iochan();
				IOStatus eos;
				int n = 0;
				int latp = -1, lonp = -1, fixp = -1, typp = -1;
				string str = null;
				size_t length = -1;
				int ft=-1,ns=-1;

				subp.complete.connect(() => {
						try {stdc.shutdown(false);} catch {};
					});

				try {
					stdc.set_encoding(null);
					for(;;) {
						eos = stdc.read_line (out str, out length, null);
						if (eos == IOStatus.EOF)
							break;
						if(str == null || length == 0)
							continue;
						var parts=str.split(",");
						if(n == 0) {
							int j = 0;
							foreach (var p in parts) {
								var pp = p.strip();
								if (pp == "GPS_fixType")
									typp = j;
								if (pp == "GPS_numSat")
									fixp = j;
								if (pp == "GPS_coord[0]")
									latp = j;
								else if(pp == "GPS_coord[1]") {
									lonp = j;
									break;
								}
								j++;
							}
							if(latp == -1 || lonp == -1 || fixp == -1 || typp == -1) {
								ProcessLauncher.kill(subp.get_pid());
								break;
							}
						} else {
							ft = int.parse(parts[typp]);
							if(ft == 2) {
								ns = int.parse(parts[fixp]);
								if(ns > 5) {
									xlat = double.parse(parts[latp]);
									xlon = double.parse(parts[lonp]);
									if(xlat != 0.0 && xlon != 0.0) {
										ok = true;
										ProcessLauncher.kill(subp.get_pid());
										break;
									}
								}
							}
						}
						n++;
					}
				} catch  (Error e) {
					MWPLog.message("BBL fbp (%d): %s\n", n, e.message);
				}
			}

			if (Rebase.is_valid()) {
				Rebase.relocate(ref xlat, ref xlon);
			}
			MWPLog.message("Getting base location from index %s %f %f %s\n", index, xlat, xlon, ok.to_string());
			return ok;
		}

		private string get_formatted_time_stamp(int j) {
			string ts = orig_times[j];
			string tss = "Invalid";
			DateTime dt = null;
			bool ok = false;
			dt = new DateTime.from_iso8601(ts,  new TimeZone.utc ());
			ok = (dt != null && dt.to_unix() > 0);
			if(ok) {
				var n = tzoption.selected;
				string tzstr = ((Gtk.StringList)tzoption.model).get_string(n);
				if(tzstr == null || tzstr == "Local" || tzstr == "") {
					tss = dt.to_local().format("%F %T %Z");
				} else {
					TimeZone tz = new TimeZone.local();
					if(tzstr == "Log")
						tzstr = ts.substring(23,6);
					try {
						tz = new TimeZone.identifier(tzstr);
					} catch (Error e) {
						MWPLog.message("TZ id failed %s %s\n", tzstr, e.message);
						tzstr = ts.substring(23,6);
						try {
							tz = new TimeZone.identifier(tzstr);
						} catch (Error e) {
							MWPLog.message(":DBG: Broken timezone db %s\n", e.message);
						}
					}
					tss = (dt.to_timezone(tz)).format("%F %T %Z");
				}
			}
			return tss;
		}

		const string GURI="http://api.geonames.org/timezoneJSON?lat=%s&lng=%s&username=%s";
		private void get_tz(double lat, double lon) {
			string str = null;
			string gmo = null;
			char cbuflat[16];
			char cbuflon[16];
			lat.format(cbuflat, "%.6f");
			lon.format(cbuflon, "%.6f");

			if(Mwp.conf.zone_detect != null && Mwp.conf.zone_detect != "") {
				var subp = new ProcessLauncher();
				var res = subp.run_argv ({Mwp.conf.zone_detect, (string)cbuflat, (string)cbuflon}, ProcessLaunch.STDOUT);
				if (res){
					var chan = subp.get_stdout_iochan();

					subp.complete.connect(() => {
							try {chan.shutdown(false);} catch {};
						});

					IOStatus eos;
					try {
						for(;;) {
							string s;
							eos = chan.read_line (out s, null, null);
							if (eos == IOStatus.EOF)
								break;
							if (s != null)
								str = s.strip();
						}
					} catch  (Error e) {
						MWPLog.message("GetTZ: %s\n", e.message);
					}
					if(str != null) {
						MWPLog.message("%s %f %f : %s\n", Mwp.conf.zone_detect, lat, lon, str);
						add_if_missing(str, true);
					}
				}
			} else if(Mwp.conf.geouser != null && Mwp.conf.geouser != "") {
				string uri = GURI.printf((string)cbuflat, (string)cbuflon, Mwp.conf.geouser);
				var session = new Soup.Session ();
				var message = new Soup.Message ("GET", uri);
				session.send_and_read_async.begin(message, 0, null, (obj,res) => {
						string s;
						try {
							var byt = session.send_and_read_async.end(res);
							s = (string) byt.get_data();
							var parser = new Json.Parser ();
							parser.load_from_data (s);
							var item = parser.get_root ().get_object ();
							if (item.has_member("timezoneId")) {
								str = item.get_string_member ("timezoneId");
							}
							if (item.has_member("gmtOffset")) {
								var gmtd = item.get_double_member ("gmtOffset");
								int gmth = (int)gmtd;
								int gmtm = (int)((gmtd - gmth)*60.0);
								gmo = "%+03d%02d".printf(gmth, gmtm);
							}

							if(str != null) {
								MWPLog.message("Geonames %f %f [%s %s]\n", lat, lon, str, gmo);
								add_if_missing(str, true);
							} else {
								MWPLog.message("Geonames: <%s>\n", uri);
								var sb = new StringBuilder("Geonames TZ: ");
								sb.append(s);
								MWPLog.message("%s\n", sb.str);
							}
						} catch {
							MWPLog.message("Geonames resp error: %d\n", message.status_code);
						}
					});
			}
		}

		public void find_bbox_box(string filename, uint index) {
			bbox = {999, 999, -999, -999};
			Thread<int> thr = null;
			thr = new Thread<int> (null, () => {
					var subp = new ProcessLauncher();
					var res = subp.run_argv (
						{Mwp.conf.blackbox_decode, "--stdout", "--index", index.to_string(), "--merge-gps", filename}, ProcessLaunch.STDOUT);
					if (res){
						var chan = subp.get_stdout_iochan();
						int latp = -1, lonp = -1, fixp = -1, typp = -1;
						string str = null;
						size_t length = -1;
						int ft=-1,ns=-1;
						double lon = 0;
						double lat = 0;
						bool hdr = false;

						try {
							chan.set_encoding(null);
							var done = false;
							for (;!done;) {
								var eos = chan.read_line (out str, out length, null);
								if (eos == IOStatus.EOF)
									done = true;
								if(str == null || length == 0)
									continue;
								var parts=str.split(",");
								if(hdr == false) {
									hdr = true;
									int j = 0;
									foreach (var p in parts) {
										var pp = p.strip();
										if (pp == "GPS_fixType")
											typp = j;
										if (pp == "GPS_numSat")
											fixp = j;
										if (pp == "GPS_coord[0]")
											latp = j;
										else if(pp == "GPS_coord[1]") {
											lonp = j;
											break;
										}
										j++;
									}
									if(latp == -1 || lonp == -1 || fixp == -1 || typp == -1) {
										ProcessLauncher.kill(subp.get_pid());
										done = true;
									}
								} else {
									ft = int.parse(parts[typp]);
									if(ft == 2) {
										ns = int.parse(parts[fixp]);
										if(ns > 5) {
											lat = double.parse(parts[latp]);
											lon = double.parse(parts[lonp]);
											if(lat < bbox.minlat)
												bbox.minlat = lat;
											if(lat > bbox.maxlat)
												bbox.maxlat = lat;
											if(lon < bbox.minlon)
												bbox.minlon = lon;
											if(lon > bbox.maxlon)
												bbox.maxlon = lon;
										}
									}
								}
							}
						} catch  (Error e) {
							print("BBL bbox: %s\n", e.message);
						}
						try { chan.shutdown(false); } catch {}
						if(bbox.minlat > -90 && bbox.maxlat < 90 && bbox.minlon > -180 && bbox.maxlon < 180) {
							if (Rebase.is_valid()) {
								Rebase.relocate(ref bbox.minlat, ref bbox.minlon);
								Rebase.relocate(ref bbox.maxlat, ref bbox.maxlon);
							}
							Idle.add(()=> { rescale();return false;});
						}
					}
					return 0;
				});
		}
	}
}