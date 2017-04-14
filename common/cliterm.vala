public class CLITerm : Gtk.Window
{
    private MWSerial s;
    private MWSerial.ProtoMode oldmode;
    private Vte.Terminal term;
    public signal void on_exit();

    public CLITerm (Gtk.Window? w = null)
    {
        this.modal = true;
        if(w != null)
        {
            this.set_transient_for (w);
        }
        this.title = "mwp CLI";
        this.window_position = Gtk.WindowPosition.CENTER;
        this.destroy.connect (() => {
                uint8 c = 4;
                s.write(&c, 1);
                s.pmode = oldmode;
                on_exit();
            });
        this.set_default_size (640, 400);

        term = new Vte.Terminal();
        term.commit.connect((text,size) => {
                switch(text[0])
                {
                    case 8:
                    uint8 c = 127;
                    s.write(&c,1);
                    break;
                    case 27:
                    break;
                    default:
                    s.write(text, size);
                    break;
                }
            });
        this.add (term);
    }

    public void configure_serial (MWSerial _s)
    {
        s = _s;
        oldmode  =  s.pmode;
        s.pmode = MWSerial.ProtoMode.CLI;
        s.cli_event.connect((buf,len) => {
                term.feed(buf);
            });
        uint8 c = '#';
        s.write(&c, 1);
    }

}
