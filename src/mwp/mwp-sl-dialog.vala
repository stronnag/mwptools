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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace SLG {
	SLG.Window bbl;
	MapUtils.BoundingBox bbox;

	public void replay_bbl(string? s) {
		bbl = new SLG.Window();
		bbl.run(s);
	}

	public const int BB_MINENTRY= 64;

	private File? bblname;

	bool is_valid ;
	bool is_broken;
	int maxidx;
	int nidx;
	uint selidx;
	bool speedup;
	uint duras;
	string videofile;
	bool vactive;
	int skiptime;
	int64 nsecs;

	SQL.Db db;

	public class SLGEntry : Object {
		public int idx  {get; construct set;}
		public string duration  {get; construct set;}
		public string timestamp  {get; construct set;}
		public int nentry {get; construct set;}
		public bool iserr  {get; construct set;}
		public bool issel  {get; construct set;}

		public SLGEntry(int idx, string timestamp, string duration, bool has_err) {
			this.idx =  idx;
			this.duration = duration;
			this.timestamp = timestamp;
			this.issel = false;
			this.iserr = has_err;
		}
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/slg_dialog.ui")]
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
		private unowned Gtk.ColumnViewColumn isok;
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

		private GLib.ListStore lstore;

		public signal void complete();

		string []orig_times;
		double clat;
		double clon;
		int zoom;

		private void setup_factories() {
			lstore = new GLib.ListStore(typeof(SLGEntry));
			var f0 = new Gtk.SignalListItemFactory();
			index.set_factory(f0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as SLGEntry;
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
					var mi = list_item.get_item() as SLGEntry;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(format_duration(mi.duration));
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
					var mi = list_item.get_item() as SLGEntry;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(mi.timestamp);
					mi.notify["timestamp"].connect((s,p) => {
							label.set_text(mi.timestamp);
						});
				});
			var f3 = new Gtk.SignalListItemFactory();
			isok.set_factory(f3);
			f3.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var btn = new Gtk.Button.from_icon_name("dialog-error-symbolic");
					list_item.set_child(btn);
					btn.clicked.connect(() => {
							var lidx = list_item.position;
							var mi = lstore.get_item(lidx) as SLGEntry;
							show_error_text(mi.idx);
						});
					btn.visible = false;
				});
			f3.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var mi = list_item.get_item() as SLGEntry;
					var btn = list_item.get_child() as Gtk.Button;
					if(mi.iserr) {
						btn.visible = true;
						btn.sensitive = true;
					}
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
					var mi = list_item.get_item() as SLGEntry;
					var ccb = list_item.get_child() as Gtk.Label;
					ccb.label = (mi.issel) ? "✔" : "";
					mi.notify["issel"].connect((s,p) => {
							ccb.label = (((SLGEntry)s).issel) ? "✔" : "";
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
						SLGEntry e = lstore.get_item(j) as SLGEntry;
						if(j == n) {
							e.issel = true;
							db.get_bounding_box(e.idx, out bbox);
							validate_bbox(ref bbox);
							var z= MapUtils.evince_zoom(bbox);
							MapUtils.centre_on(bbox.get_centre_latitude(), bbox.get_centre_longitude(), z);
						} else {
							e.issel = false;
						}
					}
				});
		}

		private string format_duration(string str) {
			var d = double.parse(str);
			var h = Math.floor(d / 3600);
			var m = Math.floor((d - (h * 3600)) / 60);
			var s = d - (h * 3600) - (m * 60);
			return "%02d:%02d:%4.1f".printf((int)h,(int)m,s);
		}

		public Window() {
			transient_for = Mwp.window;
			apply.sensitive = false;
			SLG.videofile=null;
			SLG.speedup = false;

			SLG.is_valid = false;
			SLG.is_broken = false;
			SLG.maxidx = SLG.nidx = -1;
			SLG.selidx = 0;

			SLG.nsecs = 0;
			SLG.vactive = false;
			SLG.skiptime = 0;

			MapUtils.get_centre_location(out clat, out clon);
			zoom = (int)Gis.map.viewport.zoom_level;

			orig_times = {};

			setup_factories();

			apply.clicked.connect((id) => {
					SLG.speedup = this.speedup.active;
					SLG.vactive = vidbutton.active;
					SLG.skiptime = int.parse(skip_entry.text);
					if(SLG.vactive) {
						bool neg = false;
						var s = min_entry.text;
						if (s.has_prefix("-")) {
							neg = true;
						}
						var mins = (int.parse(min_entry.text)).abs();
						var secs = DStr.strtod(sec_entry.text);
						SLG.nsecs = (int64)((mins*60 + secs)*1e9);
						if(neg && SLG.nsecs > 0) { // for the '-0' case
							SLG.nsecs *= -1;
						}
					}
					var o = lstore.get_item(selidx) as SLGEntry;
					if (o != null) {
						SLG.duras = uint.parse(o.duration);
					}
					MWPLog.message("BBL Complete\n");
					var z= MapUtils.evince_zoom(bbox);
					MapUtils.centre_on(bbox.get_centre_latitude(), bbox.get_centre_longitude(), z);
					if(videofile != null && videofile != "") {
						MWPLog.message("BBL videofile %s offset=%d\n", videofile, nsecs);
					}
					if(SLG.speedup) {
						videofile = null;
						vactive = false;
					}

					SLGEntry e = lstore.get_item(selidx) as SLGEntry;
					var sp = new SQLPlayer();
					sp.init(db, e.idx);
					close();
				});

			cancel.clicked.connect(() => {
					MapUtils.centre_on(clat, clon, zoom);
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
						{"Flightlog", {"TXT", "bbl", "csv" }},
					};
					var fc = IChooser.chooser(Mwp.conf.logpath, ifm);
					fc.title = "Open Flightlog File";
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
				var be = lstore.get_item(i) as SLGEntry;
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
			var subp = new ProcessLauncher();
			string sqlfile = "/tmp/mwp-flightlog.db";
			bool is_valid = false;
			var res = subp.run_argv({"flightlog2kml", "-interval", "100", "-sql", sqlfile, bblname.get_path()}, ProcessLaunch.STDOUT);
            size_t len = 0;
			string? line = null;
			if(res) {
				var errc = subp.get_stdout_iochan();
				errc.add_watch (IOCondition.IN|IOCondition.HUP, (src, cond) => {
						try {
							if (cond == IOCondition.HUP)
								return false;
							IOStatus eos = src.read_line (out line, out len, null);
							if(eos == IOStatus.EOF)
								return false;
							if(line == null || len == 0)
								return false;

							var parts = line.split("\t");
							if (parts.length > 3) {
								bool has_err = false;
								int nitems = int.parse(parts[3]);
								int nidx = int.parse(parts[0]);
								if (nitems > BB_MINENTRY) {
									is_valid = true;
									if (parts.length == 5) {
										has_err = true;
									}
									var ds = parts[1];
									var dp = ds.split(" ");
									var dstr = "%s %s%s".printf(dp[0], dp[1], dp[2]);
									orig_times += dstr;
									var b = new SLGEntry(nidx, dstr, parts[2], has_err);
									lstore.append(b);
								}
								MWPLog.message("Read log %d %d %s\n", nidx, nitems, has_err.to_string() );
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
							set_normal("No valid log detected.\n");
						} else {
							db = new SQL.Db("/tmp/mwp-flightlog.db");
							process_tz_record();
						}
					});
			} else {
				MWPLog.message("Failed to run flightlog2kml\n");
			}
		}

		private void process_tz_record() {
			double xlat,xlon;
			db.get_bounding_box(1, out bbox);
			validate_bbox(ref bbox);
			xlat = bbox.get_centre_latitude();
			xlon = bbox.get_centre_longitude();
			MapUtils.centre_on(xlat, xlon);
			get_tz(xlat, xlon);
		}

		private void validate_bbox(ref MapUtils.BoundingBox bbox) {
			if(bbox.minlat > -90 && bbox.maxlat < 90 && bbox.minlon > -180 && bbox.maxlon < 180) {
				if (Rebase.is_valid()) {
					Rebase.relocate(ref bbox.minlat, ref bbox.minlon);
					Rebase.relocate(ref bbox.maxlat, ref bbox.maxlon);
				}
			}
		}

		private void show_error_text(int idx) {
			var s = db.get_errors(idx);
			if (s != null) {
				string title = "<b>Damaged Log</b>";
				StringBuilder sb = new StringBuilder();
				sb.append(s);
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
				var wb = new Utils.Warning_box(title, 0, this, sw);
				wb.present();
			}
		}

		private void set_normal(string label) {
			bb_items.label = label;
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
						tzstr = ts.substring(23,5);
					try {
						tz = new TimeZone.identifier(tzstr);
					} catch (Error e) {
						MWPLog.message("TZ id failed %s %s\n", tzstr, e.message);
						tzstr = ts.substring(23,5);
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

	}
}
