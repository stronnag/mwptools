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

public class  OTXDialog : Object
{
    enum Column {
        IDX,
        STAMP,
        DURATION,
        LINES,
        NO_COLS
    }

    private string filename;
    private Gtk.Dialog dialog;
    private Gtk.Button otx_cancel;
    private Gtk.Button otx_ok;
    private Gtk.TreeView otx_treeview;
    private Gtk.ListStore otx_liststore;
    private Gtk.ComboBoxText otx_combo;
    private Gtk.FileChooserButton otx_filechooser;
    private Gtk.TreeSelection otx_sel;
    private Gtk.Window _w;
    public bool x_fl2ltm = false;

    public OTXDialog(Gtk.Builder builder, Gtk.Window? w = null,
                     string? logpath = null) //, FakeOffsets? _fo = null)
    {
        _w = w;
        dialog = builder.get_object ("otx_dialog") as Gtk.Dialog;
        otx_cancel = builder.get_object ("otx_cancel") as Button;
        otx_ok = builder.get_object ("otx_ok") as Button;
        otx_treeview = builder.get_object ("otx_treeview") as TreeView;
        otx_filechooser = builder.get_object("otx_filechooser") as FileChooserButton;
        otx_combo = builder.get_object("otx_combo") as ComboBoxText;

        otx_liststore = new Gtk.ListStore (Column.NO_COLS,
                                           typeof (int),
                                           typeof (string),
                                           typeof (string),
                                           typeof (int));
        otx_treeview.set_model (otx_liststore);
        otx_treeview.insert_column_with_attributes (-1, "Index",
                                                    new Gtk.CellRendererText (), "text",
                                                    Column.IDX);
        otx_treeview.insert_column_with_attributes (-1, "TimeStemp",
                                                    new Gtk.CellRendererText (), "text",
                                                    Column.STAMP);
        otx_treeview.insert_column_with_attributes (-1, "Duration",
                                                    new Gtk.CellRendererText (), "text",
                                                    Column.DURATION);
        otx_treeview.insert_column_with_attributes (-1, "Lines",
                                                    new Gtk.CellRendererText (), "text",
                                                    Column.LINES);
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("OTX Logs");
        filter.add_pattern ("*.csv");
        otx_filechooser.add_filter (filter);

        if(logpath != null)
            otx_filechooser.set_current_folder (logpath);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        otx_filechooser.set_action(FileChooserAction.OPEN);
        otx_filechooser.add_filter (filter);

        otx_filechooser.file_set.connect(() => {
                filename = otx_filechooser.get_filename();
                otx_liststore.clear();
                get_otx_metas();
            });

        otx_sel =  otx_treeview.get_selection();

        otx_sel.changed.connect(() => {
                otx_ok.sensitive = true;
            });

        otx_treeview.row_activated.connect((p,c) => {
                dialog.response(1001);
            });

        dialog.title = "mwp OTX Log replay";
        dialog.set_transient_for(w);
    }

    public void get_index(out string fname, out int idx, out int dura)
    {
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        otx_sel.get_selected (out model, out iter);
        Value cell;
        model.get_value (iter, Column.IDX, out cell);
        idx = (int)cell;
        fname = filename;
        model.get_value (iter, Column.DURATION, out cell);
        string duras = (string)cell;

        dura = 0;
        var parts = duras.split(":");
        if (parts.length == 2) {
            dura = int.parse(parts[0])*60 + int.parse(parts[1]);
        }
    }

    public int run()
    {
        return dialog.run();
    }

    public void hide()
    {
        dialog.hide();
    }

    private void get_otx_metas()
    {
        try {
            string[] spawn_args = {"otxlog", "--metas"};
            if (x_fl2ltm)
                spawn_args[0] = "fl2ltm";

            spawn_args += (MwpMisc.is_cygwin()==false) ? filename : MwpMisc.get_native_path(filename);
            spawn_args += null;

            int p_stdout;
            Pid child_pid;
            Process.spawn_async_with_pipes (null,
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.DO_NOT_REAP_CHILD /*|SpawnFlags.STDERR_TO_DEV_NULL*/,
                                            null,
                                            out child_pid,
                                            null,
                                            out p_stdout,
                                            null);

            IOChannel chan = new IOChannel.unix_new (p_stdout);
            IOStatus eos = 0;
            string line = "";
            size_t len = -1;

            chan.add_watch (IOCondition.IN|IOCondition.HUP, (source, condition) => {
                    if (condition == IOCondition.HUP)
                        return false;
                    try
                    {
                        eos = source.read_line (out line, out len, null);
                        if(eos == IOStatus.EOF)
                            return false;
                        if (line  == null || len == 0)
                            return true;
                        var parts = line.split(",");
                        if (parts.length == 7)
                        {
                            int flags = int.parse(parts[5]);
                            if (flags != 0) {
                                Gtk.TreeIter iter;
                                int idx = int.parse(parts[0]);
                                int istart = int.parse(parts[3]);
                                int iend= int.parse(parts[4]);
                                int dura= int.parse(parts[5]);
                                var dtext="%02d:%02d".printf(dura/60, dura%60);
                                otx_liststore.append (out iter);
                                otx_liststore.set (iter, Column.IDX, idx,
                                                   Column.STAMP, parts[2],
                                                   Column.DURATION, dtext,
                                                   Column.LINES, iend-istart+1);
                            }
                        }
                        return true;
                    } catch (IOChannelError e) {
                        stderr.printf ("IOChannelError: %s\n", e.message);
                        return false;
                    } catch (ConvertError e) {
                        stderr.printf ("ConvertError: %s\n", e.message);
                        return false;
                    }
                });
            ChildWatch.add (child_pid, (pid, status) => {
                    try { chan.shutdown(false); } catch {}
                    Process.close_pid (pid);
                });
        } catch (SpawnError e) {}
    }
}
