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

using Gtk;
using Gdl;

class LayMan : Object
{
    private DockLayout layout;
    private string confdir;
    private string layname {get; set; default = ".layout";}

    public LayMan (Dock dock, string _confdir, string? name, int count)
    {
        layout = new DockLayout (dock.master);
        confdir = _confdir;
        var xtest = new LayoutTester();

        foreach (var s in get_layout_names(confdir))
        {
            var fn = getfile(s);
            int nc;
            if((nc = xtest.read_xml_file(fn)) != count)
            {
                Posix.unlink(fn);
                MWPLog.message("Removing %s %d\n",fn,nc);
            }
        }

        if(name != null)
            layname = name;
    }

    private string getfile(string? name=null)
    {
        StringBuilder sb = new StringBuilder();
        if(name == null)
            name = layname;
        sb.append(name);
        sb.append(".xml");
//        stderr.printf("getfile() %s\n", sb.str);
        return GLib.Path.build_filename(confdir,sb.str);
    }

    public bool load_init()
    {
        bool ok = false;
        ok = (layout.load_from_file(getfile()) && layout.load_layout("mwp"));
        return ok;
    }

    public void save_config()
    {
        if(layout.is_dirty())
        {
            layout.save_layout("mwp");
        }
        layout.save_to_file(getfile());
    }

    public void save ()
    {
        var dialog = new Dialog.with_buttons ("New Layout", null,
                                              DialogFlags.MODAL |
                                              DialogFlags.DESTROY_WITH_PARENT,
                                              "Cancel", ResponseType.CANCEL,
                                              "OK", ResponseType.OK);

        var hbox = new Box (Orientation.HORIZONTAL, 8);
        hbox.border_width = 8;
        var content = dialog.get_content_area ();
        content.pack_start (hbox, false, false, 0);

        var label = new Label ("Name:");
        hbox.pack_start (label, false, false, 0);

        var entry = new Entry ();
        hbox.pack_start (entry, true, true, 0);

        hbox.show_all ();
        var response = dialog.run ();
        if (response == ResponseType.OK)
        {
            layname = entry.text;
            save_config();
        }
        dialog.destroy ();
    }

    private string[] get_layout_names(string dir, string typ=".xml")
    {
        string []files = { };
        File file = File.new_for_path (dir);

        try
        {
            FileEnumerator enumerator = file.enumerate_children (
                "standard::*",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                null);

            FileInfo info = null;
            while ((info = enumerator.next_file (null)) != null)
            {
                if (info.get_file_type () != FileType.DIRECTORY)
                {
                    var s = info.get_name();
                    if(s.has_suffix(typ))
                        files += info.get_name()[0:-4];
                }
            }
        } catch  { }
        return files;
    }

    public string restore ()
    {
        var dialog = new Dialog.with_buttons ("Restore", null,
                                      DialogFlags.MODAL |
                                              DialogFlags.DESTROY_WITH_PARENT,
                                              "Cancel", ResponseType.CANCEL,
                                              "OK", ResponseType.OK);

        Box box = new Box (Gtk.Orientation.VERTICAL, 0);
        var content = dialog.get_content_area ();
        content.pack_start (box, false, false, 0);

        string id = null;
        RadioButton b = null;
        bool found = false;

        foreach (var s in get_layout_names(confdir))
        {
            var button = new Gtk.RadioButton.with_label_from_widget (b, s);
            if(b == null)
                b = button;
            box.pack_start (button, false, false, 0);
            if(s == layname)
            {
                button.set_active(true);
                found = true;
            }
            button.toggled.connect (() => {
                    if(button.get_active())
                        id = button.label;
                });
        }

        if(!found)
            id = layname;

        box.show_all ();
        var response = dialog.run ();
        if (response == ResponseType.OK) {
//            stderr.printf("load %s\n", id);
            layname = id;
            load_init();
        }
        dialog.destroy ();
        return id;
    }
/****
    public void remove ()
    {
    }

    public void clear ()
    {
    }
***/
}
