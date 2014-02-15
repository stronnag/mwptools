
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

public class PIDEdit : Object
{
    private Gtk.Builder builder;
    private Gtk.Window window;
    private Gtk.Grid grid;
    private Gtk.SpinButton[] spins;
    private Gtk.Button conbutton;
    private Gtk.Label verslab;
    private MWSerial s;
    private string serdev;
    private uint8[] rawbuf;
    private bool is_connected;
    private bool have_pids;
    private bool have_vers;

    private void get_factors(int r, int c,
                            out double dmax, out double dmult,
                            out bool hideme)
    {
        hideme=false;
        dmult = dmax = 0.0;
        switch(c)
        {
            case 0:
                dmult = 0.1;
                dmax = 20;
                break;
            case 1:
                dmult = 0.001;
                dmax = 0.25;
                break;
            case 2:
                dmult = 1.0;
                dmax = 100;
                break;
        }
        switch (r)
        {
            case 4:
                switch(c)
                {
                    case 0:
                        dmax = 5.0;
                        dmult = 0.01;
                        break;
                    case 1:
                        dmax = 2.5;
                        dmult = 0.1;
                        break;
                    case 2:
                        hideme = true;
                        break;
                }
                break;
            case 5:
            case 6:
                switch(c)
                {
                    case 0:
                        dmax = 25.0;
                        dmult = 0.1;
                        break;
                    case 1:
                        dmax = 2.5;
                        dmult = 0.01;
                        break;
                    case 2:
                        dmax = 0.25;
                        dmult = 0.001;
                        break;
                }
                break;
            case 8:
                if (c != 0)
                    hideme = true;
                break;
        }
    }

    private void add_cmd(MSP.Cmds cmd, void* buf, size_t len, bool *flag)
    {
        Timeout.add(1000, () => {
                if (*flag == false)
                {
                    s.send_command(cmd,buf,len);
                    return true;
                }
                else
                {
                    return false;
                }
            });
        s.send_command(cmd,buf,len);
    }

    private void get_settings(out string[] devs)
    {
        devs={};
        Settings settings = null;
        var sname = "org.mwptools.pidedit";
        var uc = Environment.get_user_data_dir();
        uc += "/glib-2.0/schemas/";

        try
        {
            SettingsSchemaSource sss = new SettingsSchemaSource.from_directory (uc, null, false);
            var schema = sss.lookup (sname, false);
            if (schema != null)
                settings = new Settings.full (schema, null, null);
            else
                settings =  new Settings (sname);
        } catch {
            stderr.printf("No settings schema\n");
            Posix.exit(-1);
        }

        if (settings != null)
        {
            devs = settings.get_strv ("device-names");
        }
    }

    PIDEdit(string[] args)
    {
        is_connected = false;
        have_pids = false;
        builder = new Gtk.Builder ();
        var fn = MWPUtils.find_conf_file("pidedit.ui");
        if (fn == null)
        {
            stderr.printf ("No UI definition file\n");
            Gtk.main_quit();
        }
        else
        {
            try
            {
                builder.add_from_file (fn);
            } catch (Error e) {
                stderr.printf ("Builder: %s\n", e.message);
                Gtk.main_quit();
            }
        }

        builder.connect_signals (null);
        window = builder.get_object ("window1") as Gtk.Window;
        window.destroy.connect (Gtk.main_quit);
        s = new MWSerial();
        s.serial_event.connect((sd,cmd,raw,len,errs) => {
                if(errs == true)
                {
                    stderr.printf("Error on cmd %c (%d)\n", cmd,cmd);
                    return;
                }
                switch(cmd)
                {
                    case MSP.Cmds.IDENT:
                    have_vers = true;
                    if(have_pids == false)
                    {
                        add_cmd(MSP.Cmds.PID,null,0, &have_pids);
                    }
                    var _mrtype = MSP.get_mrtype(raw[1]);
                    var vers="v%03d %s".printf(raw[0], _mrtype);
                    verslab.set_label(vers);
                    break;

                    case MSP.Cmds.PID:
                    have_pids = true;
                    uint8 *p = raw;
                    rawbuf = raw;
                    int idx;
                    for(var r = 0; r< 10; r++)
                    {
                        idx = r*3;
                        for (var c = 0; c < 3; c++)
                        {
                            double dmax,dmult;
                            bool hideme;
                            get_factors(r,c, out dmax, out dmult, out hideme);
                            if(hideme == false)
                            {
                                double v = (*p) * dmult;
                                if (r < 9)
                                {
                                    spins[idx].set_value(v);
                                }
                            }
                            p++;
                            idx++;
                        }
                    }
                    break;
                }
            });

        try {
            string icon=null;
            icon = MWPUtils.find_conf_file("pidedit_icon.svg");
            window.set_icon_from_file(icon);
        } catch {};

        var dentry = builder.get_object ("comboboxtext1") as Gtk.ComboBoxText;
        conbutton = builder.get_object ("button4") as Gtk.Button;
        string[] devs;
        if(args.length > 1)
        {
            foreach(string a in args[1:args.length])
                dentry.append_text(a);
        }
        get_settings(out devs);
        foreach(string a in devs)
        {
            dentry.append_text(a);
        }

        var te = dentry.get_child() as Gtk.Entry;
        te.can_focus = true;
        dentry.active = 0;

        verslab = builder.get_object ("verslab") as Gtk.Label;
        verslab.set_label("");
        grid = builder.get_object ("grid1") as Gtk.Grid;
        var refbutton = builder.get_object ("button3") as Gtk.Button;

        var savebutton = builder.get_object ("button1") as Gtk.Button;
        refbutton.clicked.connect(() => {
                have_pids = false;
                if(is_connected == true)
                {
                    add_cmd(MSP.Cmds.PID,null,0, &have_pids);
                }
            });

        savebutton.clicked.connect(() => {
                if(is_connected == true && have_pids == true)
                {
                    var n = 0;
                    foreach(Gtk.SpinButton b in spins)
                    {
                        var d = b.get_value();
                        var col = n % 3;
                        var row = n / 3;
                        double dmult,dmax;
                        bool hideme;

                        get_factors(row,col, out dmax, out dmult, out hideme);
                        if (hideme == false)
                        {
                            uint8 iv = (uint8)(d/dmult);
                            rawbuf[n] = iv;
                                }
                        n++;
                    }
//                    FileUtils.set_data ("pids.dat", rawbuf);
                    Idle.add(() => {
                            s.send_command(MSP.Cmds.SET_PID,rawbuf,30);
                            s.send_command(MSP.Cmds.EEPROM_WRITE,null, 0);
                            return false;
                        });
                }
            });

        refbutton.set_sensitive(false);
        savebutton.set_sensitive(false);

        var closebutton = builder.get_object ("button2") as Gtk.Button;
        closebutton.clicked.connect(() => {
                Gtk.main_quit();
            });

        int idx;
        spins = new Gtk.SpinButton[27];

        for(int r = 0; r < 9; r++)
        {
            idx = r*3;
            for(int c = 0; c < 3; c++)
            {
                double dmult,dmax;
                bool hideme;
                get_factors(r,c, out dmax, out dmult, out hideme);
                var spin = new Gtk.SpinButton.with_range(0.0,dmax,dmult);
                spin.set_value(0.0);
                spins[idx] = spin;
                if(hideme == false)
                    grid.attach(spin,c+1,r+1,1,1);
                else
                    spin.hide();
                idx++;
            }
        }

        conbutton.clicked.connect(() => {
                if (is_connected == false)
                {
                    serdev = dentry.get_active_text();
                    if(s.open(serdev,115200) == true)
                    {
                        is_connected = true;
                        conbutton.set_label("Disconnect");
                        refbutton.set_sensitive(true);
                        savebutton.set_sensitive(true);
                        add_cmd(MSP.Cmds.IDENT,null,0,&have_vers);
                    }
                    else
                    {
                        print("open failed\n");
                    }

                }
                else
                {
                    s.close();
                    conbutton.set_label("Connect");
                    refbutton.set_sensitive(false);
                    savebutton.set_sensitive(false);
                    verslab.set_label("");
                    have_vers = false;
                    is_connected = false;
                    have_pids = false;
                }
            });

        window.show_all();
    }


    public void run()
    {
        Gtk.main();
    }


    public static int main (string[] args)
    {
        Gtk.init(ref args);
        PIDEdit app = new PIDEdit (args);
        app.run ();
        return 0;
    }
}
