public class CLITerm : Gtk.Window {

    private Gtk.TextView view;
    private MWSerial s;
    private MWSerial.ProtoMode oldmode;
    public signal void on_exit();

    public CLITerm (Gtk.Window? w = null)
    {
        this.modal = true;
        if(w != null)
        {
            this.set_keep_above(true);
            this.set_transient_for (w);
        }
        this.title = "mwp CLI";
        this.window_position = Gtk.WindowPosition.CENTER;

        this.destroy.connect (() =>
            {
                s.write("exit\n".data, 5);
                s.pmode = oldmode;
                on_exit();
            });
        this.set_default_size (600, 400);
        Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
        this.add (box);
        Gtk.ScrolledWindow scrolled = new Gtk.ScrolledWindow (null, null);
        box.pack_start (scrolled, true, true, 0);
        view = new Gtk.TextView ();
        view.editable = false;

            /* Scroll to the end on update */
        view.size_allocate.connect(() => {
                var adj = scrolled.get_vadjustment();
                adj.set_value(adj.get_upper() - adj.get_page_size());
            });

        scrolled.add (view);

        Gtk.Entry entry = new Gtk.Entry ();
        this.add (entry);

        entry.set_placeholder_text("Enter CLI command ...");
        entry.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY, "edit-clear");		// Add a delete-button:
        entry.icon_press.connect ((pos, event) => {
                if (pos == Gtk.EntryIconPosition.SECONDARY) {
                    entry.set_text ("");
                }
            });

        entry.activate.connect (() => {
                unowned string str = entry.get_text ();
                s.write(str.data,str.length);
                s.write("\n", 1);
                entry.set_text ("");
            });
        box.pack_start (entry, false, true, 0);
        entry.grab_focus();
    }

    public void configure_serial(MWSerial _s)
    {
        s = _s;
        oldmode  =  s.pmode;
        s.pmode = MWSerial.ProtoMode.CLI;
        s.cli_event.connect((buf,len) => {
                string s;
                s =  ((string)buf).replace("\r","");
                Gtk.TextIter iter;
                view.get_buffer().get_end_iter (out  iter);
                view.get_buffer().insert(ref iter, s, -1);
            });
        s.write("#\n".data, 2);
    }
}
