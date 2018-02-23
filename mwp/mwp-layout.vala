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
using Xml;

class LayReader : Object
{
    public static int read_xml_file(string path)
    {
        int ncount  = 0;
        Parser.init ();
        Xml.Doc* doc = Parser.parse_file (path);
        if (doc == null)
        {
            stderr.printf ("File %s not found or permissions missing\n", path);
            return -1;
        }
        Xml.Node* root = doc->get_root_element ();
        if (root != null)
        {
            if (root->name.down() == "dock-layout")
            {
                parse_node (root, ref ncount);
            }
        }
        delete doc;
        Parser.cleanup();
        return ncount;
    }

    private static void parse_node (Xml.Node* node, ref int ncount)
    {
        for (Xml.Node* iter = node->children; iter != null; iter = iter->next)
        {
            if (iter->type != ElementType.ELEMENT_NODE)
            {
                continue;
            }
            switch(iter->name.down())
            {
                case  "layout":
                    for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
                    {
                        string attr_content = prop->children->content;
                        switch( prop->name)
                        {
                            case "name":
                                if(attr_content == "mwp")
                                {
                                    ncount = 0;
                                    parse_node(iter, ref ncount);
                                }
                                break;
                        }
                    }
                    break;
                case "dock":
                case "paned":
                    parse_node(iter, ref ncount);
                    break;

                case "item":
                    ncount++;
                    break;
            }
        }
    }
}


class LayMan : Object
{
    private DockLayout layout;
    private string confdir;
    private string layname {get; set; default = ".layout";}
    private int icount;

    public LayMan (Dock dock, string _confdir, string? name, int count)
    {
        icount = count;
        layout = new DockLayout (dock.master);
        confdir = _confdir;

        foreach (var s in get_layout_names(confdir))
        {
            var fn = getfile(s);
            int nc;
            if((nc = LayReader.read_xml_file(fn)) != count)
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
        if(name == null)
            name = layname;
        StringBuilder sb = new StringBuilder(name);
        sb.append(".xml");
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
        try {
            string of;
            var fd = FileUtils.open_tmp(".mwp.XXXXXX.xml", out of);
            FileUtils.close(fd);
            layout.save_to_file(of);
            if(LayReader.read_xml_file(of) == icount)
            {
                string fn = getfile();
                string lxml;
                FileUtils.get_contents(of, out lxml);
                FileUtils.set_contents(fn, lxml);
                FileUtils.remove(of);
            }
            else
            {
                MWPLog.message("Failed to save layout, remains in %s\n",
                               of);
            }
        } catch {}
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
            layname = id;
            load_init();
        }
        dialog.destroy ();
        return id;
    }
}
