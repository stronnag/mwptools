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

public class  BBoxDialog : Object
{
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
    private Gtk.CheckButton bb_force_gps;
    private Gtk.TreeSelection bb_sel;
    private Gtk.Window _w;
    private string bbox_decode;
    private int[] valid = {};
    private bool is_valid;
    private Gtk.Entry tzentry;
    private Gtk.ComboBoxText bb_tz_combo;
    private string []orig_times={};
    private string geouser;

    private const int BB_MINSIZE = (4*1024);

    public signal void new_pos(double la, double lo);

    public BBoxDialog(Gtk.Builder builder, Gtk.Window? w = null,
                      string bboxdec, string? _geouser, string? logpath = null)
    {
        _w = w;
        bbox_decode = bboxdec;
        geouser = _geouser;
        dialog = builder.get_object ("bb_dialog") as Gtk.Dialog;
        bb_cancel = builder.get_object ("bb_cancel") as Button;
        bb_ok = builder.get_object ("bb_ok") as Button;
        bb_items = builder.get_object ("bb_items") as Label;
        bb_treeview = builder.get_object ("bb_treeview") as TreeView;
        bb_liststore = builder.get_object ("bb_liststore") as Gtk.ListStore;
        bb_filechooser = builder.get_object("bb_filechooser") as FileChooserButton;
        bb_combo = builder.get_object("bb_comboboxtext") as ComboBoxText;
        bb_force_gps = builder.get_object("bb_force_gps") as CheckButton;
        bb_tz_combo = builder.get_object("bb_tz_combo") as ComboBoxText;
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("BB Logs");
        filter.add_pattern ("*.TXT");
        filter.add_pattern ("*.txt");
        bb_filechooser.add_filter (filter);

        if(logpath != null)
            bb_filechooser.set_current_folder (logpath);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        bb_filechooser.set_action(FileChooserAction.OPEN);
        bb_filechooser.add_filter (filter);

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
                if(tz_exists(str))
                    update_time_stamps();
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

        dialog.set_transient_for(w);
    }

    private void kick_gtk()
    {
        Gtk.main_iteration_do(false);
    }

    private bool tz_exists(string str)
    {
        var m = bb_tz_combo.get_model();
        Gtk.TreeIter iter;
        int i,n = -1;
        bool next;

        for(i = 0, next = m.get_iter_first(out iter);
            next; next = m.iter_next(ref iter), i++)
        {
            GLib.Value cell;
            m.get_value (iter, 0, out cell);
            if((string)cell == str)
            {
                n = i;
                break;
            }
        }
        return (n != -1);
    }

    private void add_if_missing(string str,bool top=false)
    {
        if(!tz_exists(str))
            if(top)
                bb_tz_combo.prepend_text(str);
            else
                bb_tz_combo.append_text(str);
    }

    private void get_bbox_file_status()
    {
        bb_tz_combo.active = 0;
        bb_items.label = "Analysing log ...";
        MWPCursor.set_busy_cursor(dialog);
        dialog.queue_draw();
        kick_gtk();
        find_valid();
        bb_ok.sensitive = false;
    }

    private void process_tz_record(int idx)
    {
        double xlat,xlon;
        if(find_base_position(filename, idx.to_string(),
                              out xlat, out xlon))
        {
            new_pos(xlat, xlon);
            kick_gtk();
            if(geouser != null)
            {
                get_tz(xlat, xlon, geouser);
                kick_gtk();
            }
        }
    }

    private void find_valid()
    {
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

            error.add_watch (IOCondition.IN, (source, condition) => {
                    try
                    {
                        if (condition == IOCondition.HUP)
                            return false;
                        IOStatus eos = source.read_line (out line, null,null);
                        if(eos == IOStatus.EOF)
                            return false;
                        int idx=0, offset, size=0;
                        lines += line;
                        if(line.scanf(" %d %d %d", &idx, &offset, &size) == 3)
                        {
                            if(size > BB_MINSIZE)
                            {
                                is_valid = true;
                                valid += idx;
                            }
                            else
                                valid += 0;
                            maxidx = idx;
                        }
                        else if(line.has_prefix("Log 1 of"))
                        {
                            valid += 1;
                            maxidx = 1;
                            is_valid = true;
                            Posix.kill(child_pid, Posix.Signal.QUIT);
                            return false;
                        }
                        return true;
                    } catch (IOChannelError e) {
                        print ("IOChannelError: %s\n", e.message);
                        return false;
                    } catch (ConvertError e) {
                        print ("ConvertError: %s\n", e.message);
                        return false;
                    }
                });
            ChildWatch.add (child_pid, (pid, status) => {
                    Process.close_pid (pid);
                    if(!is_valid)
                    {
                        StringBuilder sb = new StringBuilder("No valid log detected.\n");
                        if(lines.length > 0)
                        {
                            sb.append("blackbox_decode says: ");
                            foreach(var l in lines)
                                sb.append(l.strip());
                        }
                        set_normal(sb.str);
                    }
                    else
                    {
                        kick_gtk();
                        var tsslen = find_start_times();
                        kick_gtk();
                        spawn_decoder(0, tsslen);
                    }
                });
        } catch (SpawnError e) {
            show_child_err(e.message);
        }
    }

    private int find_start_times()
    {
        var n = 0;
        orig_times = {};
        bool first_ok = false;
        FileStream stream = FileStream.open (filename, "r");
        if (stream != null)
        {
            char buf[1024];
            while (stream.gets (buf) != null) {
                kick_gtk();
                if(buf[0] == 'H' && buf[1] == ' ')
                {
                    if(((string)buf).has_prefix("H Log start datetime:"))
                    {
                        int len = ((string)buf).length;
                        buf[len-1] = 0;
                        string ts = (string)buf[21:len-1];
                        orig_times += ts;
                        n++;
                        if(first_ok == false && ts.has_prefix("20"))
                        {
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

    private string get_formatted_time_stamp(int j)
    {
        string ts = orig_times[j];
        string tss = "Invalid";
        TimeVal tv;
        DateTime dt;
        tv = TimeVal();
        if(tv.from_iso8601(ts))
        {
            if(tv.tv_sec > 0)
            {
                dt = new DateTime.from_timeval_utc (tv);
                string tzstr = bb_tz_combo.get_active_text ();
                if(tzstr == null || tzstr == "Local" ||
                   tzstr == "")
                {
                    tss = dt.to_local().format("%F %T %Z");
                }
                else
                {
                    if(tzstr == "Log")
                        tzstr = ts.substring(23,6);
                    TimeZone tz = new TimeZone(tzstr);
                    tss = (dt.to_timezone(tz)).format("%F %T %Z");
                }
            }
        }
        return tss;
    }

    private void update_time_stamps()
    {
        if(is_valid)
        {
            int j = 0;
            Gtk.TreeIter iter;
            for(bool next=bb_liststore.get_iter_first(out iter); next;
                next=bb_liststore.iter_next(ref iter))
            {
                GLib.Value cell;
                bb_liststore.get_value(iter, 2, out cell);
                if((string)cell != "Unknown" && (string)cell != "Invalid")
                {
                    var tsval = get_formatted_time_stamp(j);
                    bb_liststore.set_value (iter, 2, tsval);
                }
                j++;
            }
        }
    }

    private void spawn_decoder(int j, int tsslen)
    {
        for(;j < maxidx && valid[j] == 0; j++)
            ;

        if(j == maxidx)
        {
            set_normal("File contains %d %s".printf(maxidx, (maxidx == 1) ? "entry" : "entries"));
            return;
        }
        nidx = j+1;

        try
        {
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
                    try
                    {
                        string line;
                        IOStatus eos = error.read_line (out line, null,null);
                        if(eos == IOStatus.EOF)
                        {
                            return false;
                        }

                        int n;
                        n = line.index_of("Log ");
                        if(n == 0)
                        {
                            int slen = line.length;
                            n = line.index_of(" duration ");
                            if(n > 16)
                            {
                                Gtk.TreeIter iter;
                                n += 10;
                                string dura = line.substring(n, slen - n -1);
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
                        print ("IOChannelError: %s\n", e.message);
                        return false;
                    } catch (ConvertError e) {
                        print ("ConvertError: %s\n", e.message);
                        return false;
                    }
                });
            ChildWatch.add (child_pid, (pid, status) => {
                    Process.close_pid (pid);
                    spawn_decoder(j+1, tsslen);
                });
        } catch (SpawnError e) {
            show_child_err(e.message);
        }
    }

    private void set_normal(string label)
    {
        bb_items.label = label;
        MWPCursor.set_normal_cursor(dialog);
    }

    private void show_child_err(string e)
    {
        var s = "Running blackbox_decode failed (is it on the PATH?)\n%s\n".printf(e);
        MWPLog.message(s);
        var msg = new Gtk.MessageDialog (_w,
                                         Gtk.DialogFlags.MODAL,
                                         Gtk.MessageType.WARNING,
                                         Gtk.ButtonsType.OK,
                                         s);
            msg.run();
            msg.destroy();
    }

    public int run(string? fn = null)
    {
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
        }
        catch (SpawnError e) {
            show_child_err(e.message);
            id = -1;
        }

        if(id == 0)
        {
            dialog.show_all ();
            if(fn != null)
            {
                filename = fn;
                bb_filechooser.set_filename(fn);
                bb_liststore.clear();
                maxidx = -1;
                bb_items.label = "";
                get_bbox_file_status();
            }
            id = dialog.run();
            MWPCursor.set_normal_cursor(dialog);
            dialog.hide();
        }
        return id;
    }

    public void get_result(out string _name, out int _index, out int _type, out bool _use_gps_cse)
    {
        _name = filename;
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        bb_sel.get_selected (out model, out iter);
        Value cell;
        model.get_value (iter, 0, out cell);
        _index = (int)cell;
        _type = bb_combo.active -1;
        _use_gps_cse = bb_force_gps.active;
    }


    private bool find_base_position(string filename, string index,
                            out double xlat, out double xlon)
    {
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
            IOStatus eos;
            int n = 0;
            int latp = -1, lonp = -1, fixp = -1, typp = -1;
            string str = null;
            size_t length = -1;
            int ft=-1,ns=-1;

            try {
                for(;;)
                {
                    eos = chan.read_line (out str, out length, null);
                    if (eos == IOStatus.EOF)
                        break;
                    kick_gtk();
                    var parts=str.split(",");
                    if(n == 0)
                    {
                        int j = 0;
                        foreach (var p in parts)
                        {
                            var pp = p.strip();
                            if (pp == "GPS_fixType")
                                typp = j;
                            if (pp == "GPS_numSat")
                                fixp = j;
                            if (pp == "GPS_coord[0]")
                            latp = j;
                            else if(pp == "GPS_coord[1]")
                            {
                                lonp = j;
                                break;
                            }
                            j++;
                        }
                        if(latp == -1 || lonp == -1 || fixp == -1 || typp == -1)
                            break;
                    }
                    else
                    {
                        ft = int.parse(parts[typp]);
                        if(ft == 2)
                        {
                            ns = int.parse(parts[fixp]);
                            if(ns > 5)
                            {
                                xlat = double.parse(parts[latp]);
                                xlon = double.parse(parts[lonp]);
                                ok = true;
                                break;
                            }
                        }
                    }
                    n++;
                }
            } catch  (Error e) {
                print("%s\n", e.message);
            }
            Process.close_pid (child_pid);
        } catch (SpawnError e) {
            print("%s\n", e.message);
        }
        return ok;
    }

    const string GURI="http://api.geonames.org/timezoneJSON?lat=%f&lng=%f&username=%s";
    private void get_tz(double lat, double lon, string user)
    {
        string str = null;
        string uri = GURI.printf(lat, lon, user);
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", uri);
        string s="";
        session.queue_message (message, (sess, mess) => {
                if ( mess.status_code == 200)
                {
                    s = (string) mess.response_body.flatten ().data;
                    try
                    {
                        var parser = new Json.Parser ();
                        parser.load_from_data (s);
                        var item = parser.get_root ().get_object ();
                        if (item.has_member("timezoneId"))
                            str = item.get_string_member ("timezoneId");
                    } catch { }
                }

                if(str == null)
                {
                    var sb = new StringBuilder("Geonames TZ: ");
                    sb.append((string) mess.response_body.flatten ().data);
                    MWPLog.message(sb.str);
                }
                else
                {
                    add_if_missing(str);
                }
            });
    }
}
