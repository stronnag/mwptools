
public class GSPowerSettings : GLib.Object {
    private bool idleact=false;
    private bool idim=false;
    private int isleep=0;
    private bool ison = false;
    private Settings isettings;
    private Settings psettings;
    private uint8 managed = 0;

    public GSPowerSettings()
    {
        var dirs = Environment.get_system_data_dirs();
        foreach (var d in dirs)  {
            try
            {
                var ds = d + "/glib-2.0/schemas/";
                var sss = new SettingsSchemaSource.from_directory (ds, null, false);
                if ((managed & 1) == 0)
                {
                    var schema = sss.lookup ("org.gnome.desktop.screensaver", false);
                    if (schema != null) {
                        isettings = new Settings.full ( schema, null, null);
                        idleact= isettings.get_boolean ("idle-activation-enabled");
                        managed |= 1;
                    }
                }

                if ((managed & 2) == 0)
                {
                    var schema = sss.lookup ("org.gnome.settings-daemon.plugins.power", false);
                    if (schema != null) {
                        psettings = new Settings.full ( schema, null, null);
                        idim = psettings.get_boolean ("idle-dim");
                        isleep =  psettings.get_int ("sleep-inactive-battery-timeout");
                        managed |= 2;
                    }
                }
            } catch {}
            if(managed == 3)
                break;
        }
    }

    public uint8 is_managed()
    {
        return managed;
    }

    public bool SetScreen(bool on)
    {
        bool xison = ison;
        if (managed != 0)
        {
            var iae = idleact;
            var idm = idim;
            var islp = isleep;

            if (on && !ison) {
                ison = true;
                iae = false;
                idm = false;
                islp = 0;
            } else if (ison) {
                ison = false;
                iae = idleact;
                idm = idim;
                islp = isleep;
            }
            if ((managed & 1) == 1) {
                isettings.set_boolean ("idle-activation-enabled", iae);
            }
            if ((managed & 2) == 2) {
                psettings.set_boolean ("idle-dim", idm);
                psettings.set_int ("sleep-inactive-battery-timeout", islp);
            }
        }
        return xison;
    }
}

#if TEST
int main (string[] args)
{
    var gs = new GSPowerSettings();
    gs.SetScreen(true);
    stdout.printf("Disable saver ... hit enter : ");
    stdin.getc ();
    gs.SetScreen(false);
    return 0;
}
#endif
