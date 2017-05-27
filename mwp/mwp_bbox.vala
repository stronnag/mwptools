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

    public BBoxDialog(Gtk.Builder builder, int mrtype = 3, Gtk.Window? w = null,
                      string? logpath = null)
    {
        _w = w;
        dialog = builder.get_object ("bb_dialog") as Gtk.Dialog;
        bb_cancel = builder.get_object ("bb_cancel") as Button;
        bb_ok = builder.get_object ("bb_ok") as Button;
        bb_items = builder.get_object ("bb_items") as Label;
        bb_treeview = builder.get_object ("bb_treeview") as TreeView;
        bb_liststore = builder.get_object ("bb_liststore") as Gtk.ListStore;
        bb_filechooser = builder.get_object("bb_filechooser") as FileChooserButton;
        bb_combo = builder.get_object("bb_comboboxtext") as ComboBoxText;
        bb_force_gps = builder.get_object("bb_force_gps") as CheckButton;
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("BB Logs");
        filter.add_pattern ("*.TXT");
        bb_filechooser.add_filter (filter);

        if(logpath != null)
            bb_filechooser.set_current_folder (logpath);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        bb_filechooser.set_action(FileChooserAction.OPEN);
        bb_filechooser.add_filter (filter);
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

        string [] mrtypes = {"marker", "TRI", "QUADP","QUADX", "BI",
            "GIMBAL","Y6","HEX6","FLYING_WING","Y4","HEX6X","OCTOX8",
            "OCTOFLATP","OCTOFLATX","AIRPLANE/SINGLECOPTER,DUALCOPTER",
            "HELI_120","HELI_90","VTAIL4","HEX6H" };

        foreach(var ts in mrtypes)
            bb_combo.append_text (ts);
        bb_combo.active = mrtype;


        bb_treeview.row_activated.connect((p,c) => {
                dialog.response(1001);
            });

        dialog.set_transient_for(w);
    }

    private void get_bbox_file_status()
    {
        nidx = 1;
        MWPCursor.set_busy_cursor(dialog);
        spawn_decoder();
        bb_ok.sensitive = false;
    }

    private void spawn_decoder()
    {
        try {
            string[] spawn_args = {"blackbox_decode", "--stdout",
                                   "--index", "%d".printf(nidx),
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

		// stderr:
            string loginfo = null;
            IOChannel error = new IOChannel.unix_new (p_stderr);
            error.add_watch ((IOCondition.IN|IOCondition.HUP),
                             (channel, condition) => {
                                 Gtk.TreeIter iter;
                                 try {
                                     if((condition & IOCondition.IN) == IOCondition.IN)
                            {
                                IOStatus eos;
                                eos = channel.read_to_end (out loginfo, null);
                                if(eos == IOStatus.NORMAL)
                                {
                                    var lines = loginfo.split("\n");
                                    foreach(var line in lines)
                                    {
                                        int n;
                                        n = line.index_of("Log ");
                                        if(n == 0)
                                        {
                                            int slen = line.length;
                                            nidx = int.parse(line[n+4:slen]);
                                            n = line.index_of(" of ");
                                            maxidx = int.parse(line[n+4:slen]);
                                            bb_items.label = "Log %d of %d".printf(nidx,maxidx);
                                            n = line.index_of(" duration ");
                                            if(n > 16)
                                            {
                                                n += 10;
                                                string dura = line.substring(n, slen - n -1);
                                                bb_liststore.append (out iter);
                                                bb_liststore.set (iter, 0, nidx, 1, dura);
                                            }
                                        }
                                    }
                                }
                            }
                            if((condition & IOCondition.HUP) == IOCondition.HUP)
                            {
                                return false;
                            }

                        } catch (IOChannelError e) {
                            return false;
                        } catch (ConvertError e) {
                            return false;
                        }
                        return true;
                    });
		ChildWatch.add (child_pid, (pid, status) => {
                        Posix.close(p_stderr);
                        Process.close_pid (pid);
                        if(nidx == maxidx)
                        {
                            MWPCursor.set_normal_cursor(dialog);
                            if((int)bb_liststore.iter_n_children(null) == 1)
                            {
                                Gtk.TreeIter iter;
                                Gtk.TreePath path = new Gtk.TreePath.from_string ("0");
                                bb_liststore.get_iter (out iter, path);
                                bb_sel.select_iter(iter);
                            }
                            bb_items.label = "File contains %d %s".printf(
                                maxidx, (maxidx == 1) ? "entry" : "entries");
                        }
                        else if (maxidx == -1)
                        {
                            StringBuilder sb = new StringBuilder ();
                            sb.append("No valid log detected.\n");
                            if(loginfo != null)
                            {
                                sb.append("blackbox_decode says: ");
                                sb.append(loginfo.strip());
                            }
                            else
                                sb.append("Please use blackbox_decode to identify the problem with the log file");
                            bb_items.label = sb.str;
                            MWPCursor.set_normal_cursor(dialog);
                        }
                        else
                        {
                            nidx++;
                            spawn_decoder();
                        }
                    });
	} catch (SpawnError e) {
            show_child_err(e.message);
        }
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
            string[] spawn_args = {"blackbox_decode", "--help"};
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
        _type = bb_combo.active;
        _use_gps_cse = bb_force_gps.active;
    }
}
