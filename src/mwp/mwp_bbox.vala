using Gtk;

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

public class  BBoxDialog : Object {
    private string filename;
    private int nidx;
    private int maxidx;
    private Gtk.Dialog dialog;
    private Gtk.Button bb_cancel;
    private Gtk.Button bb_ok;
    private Gtk.Label bb_items;
    private Gtk.TreeView bb_treeview;
    private Gtk.ListStore bb_liststore;
    private Gtk.ComboBoxText bb_combo;
    private Gtk.FileChooserButton bb_filechooser;
    private Gtk.FileChooserButton bb_videochooser;
    private Gtk.CheckButton bb_force_gps_cog;
    private Gtk.CheckButton bb_force_gps_alt;
    private Gtk.TreeSelection bb_sel;
	private Gtk.CheckButton bb_vstart;
	private Gtk.Entry bb_vmins;
	private Gtk.Entry bb_vsecs;
	private Gtk.Window _w;
    private string bbox_decode;
    private int[] valid = {};
    private bool is_valid;
    private Gtk.Entry tzentry;
    private Gtk.ComboBoxText bb_tz_combo;
    private string []orig_times={};
    private string geouser;
    private string zone_detect;
    private bool azoom;
    private FakeOffsets fo;

    private const int BB_MINSIZE = (10*1024);

	public signal void complete(int id);
    public signal void new_pos(double la, double lo);
    public signal void rescale(double lly, double llx, double ury, double urx);
	public signal void videofile(string fn);

    public BBoxDialog(Gtk.Builder builder, Gtk.Window? w = null,
                      string bboxdec,  string? logpath = null, FakeOffsets _fo) {
        _w = w;
        bbox_decode = bboxdec;
        fo = _fo;

        dialog = builder.get_object ("bb_dialog") as Gtk.Dialog;
        bb_cancel = builder.get_object ("bb_cancel") as Button;
        bb_ok = builder.get_object ("bb_ok") as Button;
        bb_items = builder.get_object ("bb_items") as Label;
        bb_treeview = builder.get_object ("bb_treeview") as TreeView;
        bb_liststore = builder.get_object ("bb_liststore") as Gtk.ListStore;
        bb_filechooser = builder.get_object("bb_filechooser") as FileChooserButton;
        bb_videochooser = builder.get_object("bb_video") as FileChooserButton;
        bb_combo = builder.get_object("bb_comboboxtext") as ComboBoxText;
        bb_force_gps_cog = builder.get_object("bb_force_gps_cog") as CheckButton;
        bb_force_gps_alt = builder.get_object("bb_force_gps_alt") as CheckButton;
        bb_tz_combo = builder.get_object("bb_tz_combo") as ComboBoxText;
		bb_vstart = builder.get_object("bb_vstart") as CheckButton;
		bb_vmins = builder.get_object("bb_vmins") as Entry;
		bb_vsecs = builder.get_object("bb_vsecs") as Entry;

		var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("BB Logs");
        filter.add_pattern ("*.bbl");
        filter.add_pattern ("*.BBL");
        filter.add_pattern ("*.TXT");
        filter.add_pattern ("*.txt");
        bb_filechooser.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        bb_filechooser.add_filter (filter);
        bb_filechooser.set_action(FileChooserAction.OPEN);
		if(logpath != null)
            bb_filechooser.set_current_folder (logpath);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Video files");
        filter.add_pattern ("*.mkv");
        filter.add_pattern ("*.webm");
        filter.add_pattern ("*.mp4");
        bb_videochooser.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        bb_videochooser.add_filter (filter);
        bb_videochooser.set_action(FileChooserAction.OPEN);

        var tzstr = Environment.get_variable("MWP_BB_TZ");
        if(tzstr != null)
            foreach(var ts in tzstr.split(","))
                add_if_missing(ts);

        tzentry = bb_tz_combo.get_child() as Gtk.Entry;
        bb_tz_combo.active = 0;

        tzentry.activate.connect (() => {
                unowned string str = tzentry.get_text ();
                add_if_missing(str,true);
                update_time_stamps();
            });

        bb_tz_combo.changed.connect(() => {
                unowned string str = tzentry.get_text ();
                int n;
                if(tz_exists(str,out n))
                    update_time_stamps();
            });

        bb_videochooser.file_set.connect(() => {
				var uri = bb_videochooser.get_filename();
				videofile(uri);
			});

        bb_filechooser.file_set.connect(() => {
                filename = bb_filechooser.get_filename();
                bb_liststore.clear();
                maxidx = -1;
                bb_items.label = "";
                get_bbox_file_status();
            });

        bb_sel =  bb_treeview.get_selection();

        bb_sel.changed.connect(() => {
                bb_ok.sensitive = true;
            });

        bb_treeview.row_activated.connect((p,c) => {
                dialog.response(1001);
            });

        dialog.title = "mwp BBL replay";
        dialog.set_transient_for(w);

        azoom =(Environment.get_variable("MWP_BB_NOZOOM") == null) ;
        MWPLog.message("BB load async map zoom : %s\n", azoom.to_string());
    }

	public void set_tz_tools(string? _geouser, string? _zone_detect) {
        geouser = _geouser;
        zone_detect = _zone_detect;
    }

    private bool tz_exists(string str, out int row_count) {
        var m = bb_tz_combo.get_model();
        Gtk.TreeIter iter;
        int i,n = -1;
        bool next;

        for(i = 0, next = m.get_iter_first(out iter); next; next = m.iter_next(ref iter), i++) {
            GLib.Value cell;
            m.get_value (iter, 0, out cell);
            if((string)cell == str)
                n = i;
        }
        row_count = (n == -1) ? i : n;
        return (n != -1);
    }

    private int add_if_missing(string str,bool top=false) {
        int nrow = 0;
        if(!tz_exists(str, out nrow))
            if(top)
                bb_tz_combo.prepend_text(str);
            else
                bb_tz_combo.append_text(str);
        return nrow;
    }

    private void get_bbox_file_status() {
        bb_tz_combo.active = 0;
        bb_items.label = "Analysing log ...";
        MWPCursor.set_busy_cursor(dialog);
        find_valid();
        bb_ok.sensitive = false;
    }

    private void process_tz_record(int idx) {
        double xlat,xlon;
        if(find_base_position(filename, idx.to_string(),
                              out xlat, out xlon)) {
            if (azoom)
                new_pos(xlat, xlon);
            get_tz(xlat, xlon);
        }
    }

    private void find_valid() {
        is_valid = false;
        valid = {};
        maxidx = -1;
        try {
            string[] spawn_args = {bbox_decode, "--stdout", filename};
            Pid child_pid;
            int p_stderr;
            Process.spawn_async_with_pipes (null,
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.DO_NOT_REAP_CHILD |
                                            SpawnFlags.STDOUT_TO_DEV_NULL,
                                            null,
                                            out child_pid,
                                            null,
                                            null,
                                            out p_stderr);

            IOChannel error = new IOChannel.unix_new (p_stderr);
            string line = null;
            string [] lines = {}; // for the error path
            size_t len = 0;

            error.add_watch (IOCondition.IN|IOCondition.HUP, (source, condition) => {
                    try {
                        if (condition == IOCondition.HUP)
                            return false;
                        IOStatus eos = source.read_line (out line, out len, null);
                        if(eos == IOStatus.EOF)
                            return false;

                        if(line == null || len == 0)
                            return true;

                        int idx=0, offset, size=0;
                        lines += line;
                        if(line.scanf(" %d %d %d", &idx, &offset, &size) == 3) {
                            if(size > BB_MINSIZE) {
                                is_valid = true;
                                valid += idx;
                            }  // else { valid += 0}; // really!!!
                            maxidx = idx;
                        } else if(line.has_prefix("Log 1 of")) {
                            valid += 1;
                            maxidx = 1;
                            is_valid = true;
                            Posix.kill(child_pid, MwpSignals.Signal.TERM);
                            return false;
                        }
                        return true;
                    } catch (IOChannelError e) {
                        MWPLog.message("IOChannelError: %s\n", e.message);
                        return false;
                    } catch (ConvertError e) {
                        MWPLog.message ("ConvertError: %s\n", e.message);
                        return false;
                    }
                });
            ChildWatch.add (child_pid, (pid, status) => {
                    try { error.shutdown(false); } catch {}
                    Process.close_pid (pid);
                    if(!is_valid) {
                        StringBuilder sb = new StringBuilder("No valid log detected.\n");
                        if(lines.length > 0) {
                            sb.append("blackbox_decode says: ");
                            foreach(var l in lines)
                                sb.append(l.strip());
                        }
                        set_normal(sb.str);
                    } else {
                        var tsslen = find_start_times();
                        spawn_decoder(0, tsslen);
                    }
                });
        } catch (SpawnError e) {
            show_child_err(e.message);
        }
    }

    private int find_start_times() {
        var n = 0;
        orig_times = {};
        bool first_ok = false;

        FileStream stream = FileStream.open (filename, "r");
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

    private string get_formatted_time_stamp(int j) {
        string ts = orig_times[j];
        string tss = "Invalid";
        DateTime dt = null;
        bool ok = false;
#if USE_TV1
        TimeVal  tv = TimeVal();
        if(tv.from_iso8601(ts)) {
          if(tv.tv_sec > 0) {
            dt = new DateTime.from_timeval_utc (tv);
            ok = true;
          }
        }
#else
        dt = new DateTime.from_iso8601(ts,  new TimeZone.utc ());
        ok = (dt.to_unix() > 0);
#endif
        if(ok) {
            string tzstr = bb_tz_combo.get_active_text ();
            if(tzstr == null || tzstr == "Local" || tzstr == "") {
                tss = dt.to_local().format("%F %T %Z");
            } else {
                TimeZone tz = new TimeZone.local();
                if(tzstr == "Log")
                    tzstr = ts.substring(23,6);
#if OLDTVI
                tz = new TimeZone(tzstr);
#else
                try {
                    tz = new TimeZone.identifier(tzstr);
                } catch { }
#endif
                tss = (dt.to_timezone(tz)).format("%F %T %Z");
            }
        }
        return tss;
    }

    private void update_time_stamps() {
        if(is_valid) {
            int j = 0;
            Gtk.TreeIter iter;
            for(bool next=bb_liststore.get_iter_first(out iter); next;
                next=bb_liststore.iter_next(ref iter)) {
                GLib.Value cell;
                bb_liststore.get_value(iter, 2, out cell);
                if((string)cell != "Unknown" && (string)cell != "Invalid") {
                    var tsval = get_formatted_time_stamp(j);
                    bb_liststore.set_value (iter, 2, tsval);
                }
                j++;
            }
        }
    }

    private void spawn_decoder(int j, int tsslen) {
        for(;j < maxidx && valid[j] == 0; j++)
            ;

        if(j == maxidx) {
            set_normal("File contains %d %s".printf(maxidx, (maxidx == 1) ? "entry" : "entries"));
            return;
        }
        nidx = j+1;

        try {
            string[] spawn_args = {bbox_decode, "--stdout",
                                   "--index", nidx.to_string(),
                                   filename};
            Pid child_pid;
            int p_stderr;

            Process.spawn_async_with_pipes (null,
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.DO_NOT_REAP_CHILD |
                                            SpawnFlags.STDOUT_TO_DEV_NULL,
                                            null,
                                            out child_pid,
                                            null,
                                            null,
                                            out p_stderr);

            IOChannel error = new IOChannel.unix_new (p_stderr);
            error.add_watch (IOCondition.IN|IOCondition.HUP, (source, condition) => {
                    if (condition == IOCondition.HUP)
                        return false;
                    try {
                        string line;
                        size_t len = 0;

                        IOStatus eos = source.read_line (out line, out len, null);
                        if(eos == IOStatus.EOF)
                            return false;
                        if (line  == null || len == 0)
                            return true;

                        int n;
                        n = line.index_of("Log ");
                        if(n == 0) {
                            n = line.index_of(" duration ");
                            if(n > 16) {
                                Gtk.TreeIter iter;
                                n += 10;
                                string dura = line.substring(n, (long)len - n -1);
                                bb_liststore.append (out iter);
                                string tsval;
                                if(tsslen > 0 && maxidx == tsslen)
                                    tsval = get_formatted_time_stamp(j);
                                else
                                    tsval = "Unknown";
                                bb_liststore.set (iter, 0, nidx, 1, dura, 2, tsval);
                            }
                        }
                        return true;
                    } catch (IOChannelError e) {
                        MWPLog.message ("IOChannelError: %s\n", e.message);
                        return false;
                    } catch (ConvertError e) {
                        MWPLog.message ("ConvertError: %s\n", e.message);
                        return false;
                    }
                });
            ChildWatch.add (child_pid, (pid, status) => {
                    try { error.shutdown(false); } catch {}
                    Process.close_pid (pid);
                    spawn_decoder(j+1, tsslen);
                });
        } catch (SpawnError e) {
            show_child_err(e.message);
        }
    }

    private void set_normal(string label) {
        bb_items.label = label;
        MWPCursor.set_normal_cursor(dialog);
    }

    private void show_child_err(string e) {
        var s = "Running blackbox_decode failed (is it on the PATH?)\n%s\n".printf(e);
        MWPLog.message(s);
        var msg = new Gtk.MessageDialog (_w,
                                         Gtk.DialogFlags.MODAL,
                                         Gtk.MessageType.WARNING,
                                         Gtk.ButtonsType.OK,
                                         s);
        msg.show_all();
        msg.response.connect((id) => {
            msg.destroy();
            });
    }

    public void run(string? fn = null) {
        int id = 0;
        try {
            string[] spawn_args = {bbox_decode, "--help"};
            Process.spawn_sync ("/",
                                spawn_args,
                                null,
                                SpawnFlags.SEARCH_PATH|
                                SpawnFlags.STDOUT_TO_DEV_NULL|
                                SpawnFlags.STDERR_TO_DEV_NULL,
                                null,
                                null,
                                null,
                                null);
        } catch (SpawnError e) {
            show_child_err(e.message);
            id = -1;
        }

        if(id == 0) {
            if(fn != null) {
                filename = fn;
                bb_filechooser.set_filename(fn);
                bb_liststore.clear();
                maxidx = -1;
                bb_items.label = "";
                get_bbox_file_status();
            }
            dialog.show_all ();
			dialog.response.connect((id) => {
					MWPCursor.set_normal_cursor(dialog);
					dialog.hide();
					complete(id);
				});
        } else {
			complete(id);
		}
	}

	public bool get_vtimer(out int64 nsecs) {
		var vauto = bb_vstart.active;
		nsecs = 0;
		if (vauto) {
			string s;
			bool neg = false;
			s = bb_vmins.text;
			if (s.has_prefix("-"))
				neg = true;
			var mins = (int.parse(s)).abs();
			var secs = DStr.strtod(bb_vsecs.text, null);
			nsecs = (int64)((mins*60 + secs)*1e9);
			if(neg && nsecs > 0) // for the '-0' case
				nsecs *= -1;
		}
		return vauto;
	}

	public void get_result(out string _name, out int _index, out int _type, out uint8 _use_gps, out uint duration) {
        _name = filename;
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        bb_sel.get_selected (out model, out iter);
        Value cell;
        model.get_value (iter, 0, out cell);
        _index = (int)cell;
        _type = bb_combo.active -1;
        _use_gps = ((bb_force_gps_cog.active) ? 1 : 0) + ((bb_force_gps_alt.active) ? 2 : 0);
        model.get_value (iter, 1, out cell);
        string s = (string)cell;
        var parts = s.split(":");
        duration = (parts.length == 2) ? (uint)int.parse(parts[0])*60 + (uint)(double.parse(parts[1])+0.5) : 0;
    }

    private bool find_base_position(string filename, string index,
                            out double xlat, out double xlon) {
        bool ok = false;
        xlon = xlat = 0;
        try {
            string[] spawn_args = {bbox_decode, "--stdout",
                                   "--index", index, "--merge-gps", filename};
            Pid child_pid;
            int p_stdout;
            Process.spawn_async_with_pipes (null,
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.DO_NOT_REAP_CHILD |
                                            SpawnFlags.STDERR_TO_DEV_NULL,
                                            null,
                                            out child_pid,
                                            null,
                                            out p_stdout,
                                            null);


            IOChannel chan = new IOChannel.unix_new (p_stdout);
			ChildWatch.add (child_pid, (pid, status) => {
                    Process.close_pid (pid);
				});

			IOStatus eos;
            int n = 0;
            int latp = -1, lonp = -1, fixp = -1, typp = -1;
            string str = null;
            size_t length = -1;
            int ft=-1,ns=-1;

            try {
                for(;;) {
                    eos = chan.read_line (out str, out length, null);
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
                            Posix.kill(child_pid, MwpSignals.Signal.TERM);
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
                                    Posix.kill(child_pid, MwpSignals.Signal.TERM);
                                    break;
                                }
                            }
                        }
                    }
                    n++;
                }
            } catch  (Error e) {
                MWPLog.message("%s\n", e.message);
            }
        } catch (SpawnError e) {
            MWPLog.message("%s\n", e.message);
        }
        if(fo.faking) {
            xlat += fo.dlat;
            xlon += fo.dlon;
        }
        MWPLog.message("Getting base location from index %s %f %f %s\n",
                       index, xlat, xlon, ok.to_string());
        return ok;
    }

    const string GURI="http://api.geonames.org/timezoneJSON?lat=%s&lng=%s&username=%s";
    private void get_tz(double lat, double lon) {
        string str = null;
		char cbuflat[16];
		char cbuflon[16];
		lat.format(cbuflat, "%.6f");
		lon.format(cbuflon, "%.6f");

        if(zone_detect != null) {
            try {
                string[] spawn_args = {zone_detect, (string)cbuflat, (string)cbuflon};
                Pid child_pid;
                int p_stdout;
                Process.spawn_async_with_pipes (null,
                                                spawn_args,
                                                null,
                                                SpawnFlags.SEARCH_PATH |
                                                SpawnFlags.DO_NOT_REAP_CHILD |
                                                SpawnFlags.STDERR_TO_DEV_NULL,
                                                null,
                                                out child_pid,
                                                null,
                                                out p_stdout,
                                                null);

				ChildWatch.add (child_pid, (pid, status) => {
						Process.close_pid (pid);
					});
				IOChannel chan = new IOChannel.unix_new (p_stdout);
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
                    MWPLog.message("%s\n", e.message);
                }
            } catch (SpawnError e) {
                MWPLog.message("%s\n", e.message);
            }
            if(str != null) {
                MWPLog.message("%s %f %f : %s\n", zone_detect, lat, lon, str);
                var n = add_if_missing(str);
                bb_tz_combo.active = n;
            }
        }
        else if(geouser != null) {
            string uri = GURI.printf((string)cbuflat, (string)cbuflon, geouser);
            var session = new Soup.Session ();
            var message = new Soup.Message ("GET", uri);
#if COLDSOUP
            string s="";
            session.queue_message (message, (sess, mess) => {
                    if (mess.status_code == 200) {
                        s = (string) mess.response_body.flatten ().data;
                        try {
                            var parser = new Json.Parser ();
                            parser.load_from_data (s);
                            var item = parser.get_root ().get_object ();
                            if (item.has_member("timezoneId"))
                                str = item.get_string_member ("timezoneId");
                        } catch {
							MWPLog.message("Geonames resp error: %d\n", mess.status_code);
						}
                    }
                    if(str != null) {
                        MWPLog.message("Geonames %f %f %s\n", lat, lon, str);
                        var n = add_if_missing(str);
                        bb_tz_combo.active = n;
                     } else {
						MWPLog.message("Geonames: <%s>\n", uri);
                        var sb = new StringBuilder("Geonames TZ: ");
                        sb.append((string) mess.response_body.flatten ().data);
                        MWPLog.message("%s\n", sb.str);
                    }
                });
#else
            session.send_and_read_async.begin(message, 0, null, (obj,res) => {
                    string s;
                    try {
                        var byt = session.send_and_read_async.end(res);
                        s = (string) byt.get_data();
                        var parser = new Json.Parser ();
                        parser.load_from_data (s);
                        var item = parser.get_root ().get_object ();
                        if (item.has_member("timezoneId"))
                            str = item.get_string_member ("timezoneId");
                        if(str != null) {
                            MWPLog.message("Geonames %f %f %s\n", lat, lon, str);
                            var n = add_if_missing(str);
                            bb_tz_combo.active = n;
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
#endif
        }
    }

    public void find_bbox_box(string filename, int index) {
        Thread<int> thr = null;
		thr = new Thread<int> (null, () => {
				double lamin = 999;
				double lamax = -999;
				double lomin = 999;
				double lomax = -999;
				try {
					Pid child_pid;
					string[] spawn_args = {bbox_decode, "--stdout",
						"--index", index.to_string(), "--merge-gps", filename};
					int p_stdout;
					Process.spawn_async_with_pipes (null,
													spawn_args,
													null,
													SpawnFlags.SEARCH_PATH |
													SpawnFlags.DO_NOT_REAP_CHILD |
													SpawnFlags.STDERR_TO_DEV_NULL,
													null,
													out child_pid,
													null,
													out p_stdout,
													null);

					IOChannel chan = new IOChannel.unix_new (p_stdout);
					ChildWatch.add (child_pid, (pid, status) => {
							Process.close_pid (pid);
						});


					int latp = -1, lonp = -1, fixp = -1, typp = -1;
					string str = null;
					size_t length = -1;
					int ft=-1,ns=-1;
					double lon = 0;
					double lat = 0;
					bool hdr = false;

					try {
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
									Posix.kill(child_pid, 15);
									done = true;
								}
							} else {
								ft = int.parse(parts[typp]);
								if(ft == 2) {
									ns = int.parse(parts[fixp]);
									if(ns > 5) {
										lat = double.parse(parts[latp]);
										lon = double.parse(parts[lonp]);
										if(fo.faking) {
											lat += fo.dlat;
											lon += fo.dlon;
										}
										if(lat < lamin)
											lamin = lat;
										if(lat > lamax)
											lamax = lat;
										if(lon < lomin)
											lomin = lon;
										if(lon > lomax)
											lomax = lon;
									}
								}
							}
						}
					} catch  (Error e) {
						print("%s\n", e.message);
					}

					try { chan.shutdown(false); } catch {}
					if(lamin > -90 && lamax < 90 && lomin > -180 && lomax < 180) {
						Idle.add(() => {
								rescale(lomin, lamin, lomax, lamax);
								return false;
							});
					}
				} catch (SpawnError e) {
					print("%s\n", e.message);
				}
                Idle.add(()=> {thr.join(); return false;});
				return 0;
			});
    }
}
