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

public class  RAWDialog : Object {
    private string filename;
    private Gtk.Dialog dialog;
    private Gtk.Button raw_cancel;
    private Gtk.Button raw_ok;
    private Gtk.ComboBoxText raw_combo;
    private Gtk.Entry raw_entry;
    private Gtk.FileChooserButton raw_filechooser;
    private Gtk.Window _w;
    private int raw_delay = 10;

    public signal void ready(int id);

    public RAWDialog(Gtk.Builder builder, Gtk.Window? w, string? logpath) {
        _w = w;
        dialog = builder.get_object ("raw_dialog") as Gtk.Dialog;
        raw_entry = builder.get_object ("raw_delay") as Entry;
        raw_cancel = builder.get_object ("raw_cancel") as Button;
        raw_ok = builder.get_object ("raw_ok") as Button;
        raw_filechooser = builder.get_object("raw_filechooser") as FileChooserButton;
        raw_combo = builder.get_object("raw_combo") as ComboBoxText;

        raw_entry.text = "%d".printf(raw_delay);

        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Raw Log Files");
        filter.add_pattern ("*.raw");
        filter.add_pattern ("*.log");
        filter.add_pattern ("*.cap");
        raw_filechooser.add_filter (filter);

        if(logpath != null)
            raw_filechooser.set_current_folder (logpath);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        raw_filechooser.set_action(FileChooserAction.OPEN);
        raw_filechooser.add_filter (filter);

        raw_filechooser.file_set.connect(() => {
                filename = raw_filechooser.get_filename();
                raw_ok.sensitive = true;
            });

        dialog.title = "mwp Raw Log replay";
		//        dialog.set_transient_for(w);
        dialog.response.connect((resp) => {
                ready(resp);
            });
    }

    public void prepare (string? fn) {
		if (fn != null) {
			filename = fn;
			raw_filechooser.set_filename(fn);
		}
        dialog.show_all();
    }

    public void hide() {
        dialog.hide();
    }

    public void get_name(out string fname, out int mtype, out int rdelay) {
        fname = filename;
        rdelay = int.parse(raw_entry.text);
        mtype = raw_combo.active -1;
    }
}
