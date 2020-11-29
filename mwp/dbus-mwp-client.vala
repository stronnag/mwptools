// valac --pkg gio-2.0 gdbus-demo-client.vala

[DBus (name = "org.mwptools.mwp")]
interface MwpIF : Object {
    public abstract uint32 load_mission (string fn) throws Error;
    public abstract void load_blackbox  (string fn) throws Error;
    public abstract void load_mwp_log (string fn) throws Error;
}

public class MwpBusClient : Object
{
    private string missionfn;
    private string bblfn;
    private string mwplogfn;
    private MainLoop ml;
    private MwpIF? proxy = null;

    public void acquire()
    {
        Bus.watch_name(BusType.SESSION, "org.mwptools.mwp",
                       BusNameWatcherFlags.NONE,
                       has_bus, lost_bus);
    }

    private void has_bus()
    {
        if (proxy == null)
            Bus.get_proxy.begin<MwpIF>(BusType.SESSION,
                                       "org.mwptools.mwp",
                                       "/org/mwptools/mwp",
                                       0, null, on_bus_get);
    }

    private void on_bus_get(Object? o, AsyncResult? res)
    {
        try {
            proxy = Bus.get_proxy.end(res);
            try
            {
                if (missionfn != null && FileUtils.test (missionfn, FileTest.EXISTS))
                {
                    proxy.load_mission (missionfn);
                }
                if (bblfn != null && FileUtils.test (bblfn, FileTest.EXISTS))
                {
                    proxy.load_blackbox (bblfn);
                }
                if (mwplogfn != null && FileUtils.test (mwplogfn, FileTest.EXISTS))
                {
                    proxy.load_mwp_log (mwplogfn);
                }
            } catch (Error f) {
                stderr.printf("%s\n", f.message);
            }

        } catch (Error e) {
            stderr.printf ("%s\n", e.message);
            proxy = null;
        }
        ml.quit();
    }

    private void lost_bus()
    {
        proxy = null;
    }

    public void  set_filename(string []s)
    {
        foreach(var fn in s)
        {
            if(fn.has_suffix(".mission") || fn.has_suffix(".json"))
            {
                missionfn = fn;
            }
            if(fn.has_suffix(".TXT") || fn.has_suffix(".bbl"))
            {
                bblfn = fn;
            }
            if(fn.has_suffix(".log"))
            {
                mwplogfn = fn;
            }
        }
    }

    public void run()
    {
        ml = new MainLoop();
        ml.run();
    }
}

/**
int main (string?[]args) {
    if(args.length > 1)
    {
        var a = new App();
        a.set_filename(args);
        a.acquire();
        a.run();
    }
    return 0;
}
**/