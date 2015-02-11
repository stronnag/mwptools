using Gtk;


/* workaround for Windows / mingw */
extern int cf_pipe(int *fds);
//extern int cf_pipe_close(int fd);

public class DumpGUI : MWSerial
{
    private Builder builder;
    private Gtk.Window window;
    private int action;
    private string filename;
    private Gtk.TextView textview;
    private Gtk.ComboBoxText devcombo;
    private Gtk.Button execbutton;
    private Gtk.Entry fileentry;
    private int[] msgpipe;

    public DumpGUI()
    {
    }

    public void init_ui(string? resfile)
    {
        builder = new Gtk.Builder ();
        try {
            builder.add_from_resource ("/org/mwptools/cf-cli/cf-cli.ui");
        } catch (Error e) {
            error ("loading menu builder file: %s", e.message);
        }
        builder.connect_signals (null);
        window = builder.get_object ("window2") as Gtk.Window;

        Gdk.Pixbuf pbuf;
        try
        {
            pbuf = new Gdk.Pixbuf.from_resource("/org/mwptools/cf-cli/cf-cli.svg");
        } catch {
            try {
                pbuf = new Gdk.Pixbuf.from_resource("/org/mwptools/cf-cli/cf-cli.png");
            } catch (Error e) {
                error ("creating icon: %s", e.message);
            }
        }
        window.icon=pbuf;
        window.destroy.connect (() => {
                Gtk.main_quit();
            });

        var b =  builder.get_object ("button2") as Gtk.Button;
        b.clicked.connect (() => {
                Gtk.main_quit();
            });

        execbutton =  builder.get_object ("button1") as Gtk.Button;
        execbutton.clicked.connect (() => {
                execbutton.sensitive=false;
                devname =  devcombo.get_active_text();
                defname = fileentry.get_text();
                if(defname != null && defname.length == 0)
                    defname = filename = null;
                else
                    filename = defname;
                perform();
            });

        var sb1 = builder.get_object ("spinbutton1") as Gtk.SpinButton;
        var sb2 = builder.get_object ("spinbutton2") as Gtk.SpinButton;
        var modebox = builder.get_object ("modecombo") as Gtk.ComboBoxText;
        var baudbox  = builder.get_object ("baudcombo") as Gtk.ComboBoxText;
        devcombo = builder.get_object ("devcombo") as Gtk.ComboBoxText;
        var chooser = builder.get_object ("filebutton") as Gtk.Button;
        fileentry = builder.get_object ("fileentry") as Gtk.Entry;
        var mergebutton = builder.get_object ("mergebutton") as Gtk.CheckButton;
        var auxbutton = builder.get_object ("auxbutton") as Gtk.CheckButton;
        var tributton = builder.get_object ("tributton") as Gtk.CheckButton;
        var savedbeforebutton = builder.get_object ("savebeforebutton") as Gtk.CheckButton;

        var te = devcombo.get_child() as Gtk.Entry;
        te.can_focus = true;

        textview = builder.get_object ("textview") as Gtk.TextView;
        var sw = builder.get_object ("scrolledwindow1") as Gtk.ScrolledWindow;
        textview.size_allocate.connect(() => {
                var adj = sw.get_vadjustment();
                adj.set_value(adj.get_upper() - adj.get_page_size());
            });


        mergebutton.active = merge;
        mergebutton.toggled.connect (() => {
                merge = mergebutton.active;
            });

        auxbutton.active = amerge;
        auxbutton.toggled.connect (() => {
                amerge = auxbutton.active;
            });

        tributton.active = tyaw;
        tributton.toggled.connect (() => {
                tyaw = tributton.active;
            });

        savedbeforebutton.active = presave;
        savedbeforebutton.toggled.connect (() => {
                presave = savedbeforebutton.active;
            });
        savedbeforebutton.sensitive = false;

        chooser.clicked.connect(() => {
              Gtk.FileChooserAction fa;
              fa = (action == 0) ? Gtk.FileChooserAction.SAVE : Gtk.FileChooserAction.OPEN;
              Gtk.FileChooserDialog fc = new Gtk.FileChooserDialog (
                  "CLI Dump file", null, fa,
                  "_Cancel",
                  Gtk.ResponseType.CANCEL,
                  (action == 0) ? "_Save" : "_Open",
                    Gtk.ResponseType.ACCEPT);
              fc.select_multiple = false;
              fc.set_do_overwrite_confirmation(true);
              if (fc.run () == Gtk.ResponseType.ACCEPT) {
                  filename  = fc.get_filename ();
                  fileentry.set_text(filename);
              }
              fc.close();
            });

        sb1.adjustment.value = prof0;
        sb2.adjustment.value = prof1;
        sb1.value_changed.connect (() => {
                prof0 = (int)sb1.adjustment.value;
                if(prof0 > prof1)
                {
                    prof1 = prof0;
                    sb2.adjustment.value = prof1;
                }
            });

        sb2.value_changed.connect (() => {
                prof1 = (int)sb2.adjustment.value;
                if(prof1 < prof0)
                {
                    prof1 = prof0;
                    sb2.adjustment.value = prof1;
                }
            });

        if(resfile != null)
        {
            modebox.active_id = "1";
            fileentry.set_text(resfile);
        }
        else if (defname != null)
        {
            fileentry.set_text(defname);
            modebox.active_id = "0";
        }

        modebox.changed.connect (() => {
                action =  int.parse(modebox.active_id);
                bool acts;
                acts = (action == 0);
                mergebutton.sensitive =
                auxbutton.sensitive = acts;
                sb1.sensitive = sb2.sensitive = acts;
                savedbeforebutton.sensitive = !acts;
            });


        devcombo.changed.connect (() => {
                devname =  devcombo.get_active_text();
            });


        baudbox.set_active_id(brate.to_string());
        baudbox.changed.connect (() => {
                brate =  int.parse(baudbox.active_id);
            });

        prof0 = (int)sb1.adjustment.value;
        prof1 = (int)sb2.adjustment.value;
        action =  int.parse(modebox.active_id);

        window.show_all();
    }

    private void update_list(string name, char action)
    {
        Gtk.TreeIter iter;
        var model = devcombo.get_model();
        var te = devcombo.get_child() as Gtk.Entry;
        int n_rows = model.iter_n_children(null);
        int n = 0;
        int k = -1;
        for(bool next=model.get_iter_first(out iter); next;
            next=model.iter_next(ref iter))
        {
            GLib.Value cell;
            model.get_value (iter, 0, out cell);
            if((string)cell == name)
            {
                k = n;
                break;
            }
            n++;
        }

        if(k == -1)
        {
            if (action != '-')
            {
                devcombo.append_text(name);
                k = n_rows;
                n_rows++;
            }
        }
        if(k != -1)
        {
            switch (action)
            {
                case '-':
                    devcombo.remove(k);
                    n_rows--;
                    if(n_rows == 0)
                    {
                        te.set_text("");
                    }
                    else
                    {
                        devcombo.set_active(n_rows-1);
                        te.set_text(devcombo.get_active_text());
                    }
                    break;
                case '*':
                    devcombo.set_active(k);
                    break;
            }
        }
    }

    public void add_to_list(string devname, int flag = 0)
    {
        char act = (flag ==  DevManager.USB_TTY_MAJOR) ? '*' : '+';
        update_list(devname, act);
    }

    public void remove_from_list(string devname)
    {
        update_list(devname, '-');
    }

    private bool io_reader (IOChannel gio, IOCondition condition)
    {
        IOStatus ret;
        string msg;
        size_t len;

        if((condition & IOCondition.IN) != IOCondition.IN)
        {
            execbutton.sensitive=true;
            Posix.close(msgpipe[0]);
            return false;
        }
        try {
            ret = gio.read_line(out msg, out len, null);
            if(ret == IOStatus.NORMAL)
            {
                Gtk.TextIter ei;
                var tbuffer = textview.get_buffer();
                tbuffer.get_end_iter(out ei);
                tbuffer.insert(ref ei, msg, -1);
                stderr.puts(msg);
                stderr.flush();
            }
            else
            {
                execbutton.sensitive=true;
                Posix.close(msgpipe[0]);
                return false;
            }
        }
        catch(IOChannelError e) {
            print("Error reading: %s\n", e.message);
        }
        catch(ConvertError e) {
            print("Error reading: %s\n", e.message);
        }
        return true;
    }

    public void perform()
    {
        IOChannel io_read;
        msgpipe = new int[2];
        cf_pipe(msgpipe);
        io_read  = new IOChannel.unix_new(msgpipe[0]);
        io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL|
                          IOCondition.ERR, io_reader);

        new Thread<int> ("cf-cli-worker", () => {
                set_iofd(msgpipe[1]);
                if(open())
                {
                    int err = fc_init();
                    if(err == 0)
                    {
                        if(action == 0)
                            perform_backup();
                        else
                            perform_restore(filename);
                    }
                }
                message("Done\n");
                Posix.close(msgpipe[1]);
                close();
                return 0;
            });
    }

    public static int  main(string [] args)
    {
        Gtk.init (ref args);
        var dg = new DumpGUI();
        int ini_res;

        string restore_file = null;
        if ((ini_res = dg.init_app(args, ref restore_file)) != 0)
            return ini_res;

        dg.init_ui(restore_file);
        var gu = new DevManager(dg);
        gu.initialise_devices();
        Gtk.main ();
        return 0;
    }
}
