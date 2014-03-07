
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

public class SwitchEdit : Object
{
    private Gtk.Builder builder;
    private Gtk.Window window;
    private Gtk.Grid grid1;
    private Gtk.Button conbutton;
    private Gtk.Label verslab;
    private MWSerial s;
    private string serdev;
    private bool is_connected;
    private bool have_box;
    private bool have_names;
    private bool have_vers;
    private Gtk.ProgressBar lvbar[8];
    private Gtk.Label[] boxlabel;
    private Gtk.CheckButton[] checks;
    private uint nboxen;
    private uint32 xflag = 0;
    private Gdk.RGBA[] colors;
    private uint tid;

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
        var sname = "org.mwptools.switchedit";
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

    SwitchEdit(string[] args)
    {
        is_connected = false;
        have_names = false;
        have_box = false;
        boxlabel = {};
        checks= {};
        colors = new Gdk.RGBA[2];
        colors[1].parse("orange");
        colors[0].parse("white");

        builder = new Gtk.Builder ();
        var fn = MWPUtils.find_conf_file("switchedit.ui");
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
        window = builder.get_object ("window2") as Gtk.Window;
        grid1 = builder.get_object ("grid1") as Gtk.Grid;
        for(var i = 0; i < 8;)
        {
            var j = i+1;
            lvbar[i] =  builder.get_object ("progressbar%d".printf(j)) as Gtk.ProgressBar;
            i = j;
        }

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
                    var _mrtype = MSP.get_mrtype(raw[1]);
                    var vers="v%03d %s".printf(raw[0], _mrtype);
                    verslab.set_label(vers);
                    add_cmd(MSP.Cmds.BOXNAMES,null,0,&have_names);
                    break;

                    case MSP.Cmds.BOXNAMES:
                    have_names = true;
                    string b = (string)raw;
                    string []bsx = b.split(";");
                    nboxen = bsx.length-1;

                    for(var i = 0; i < nboxen; i++)
                    {
                        var l = new Gtk.Label("");
                        l.set_width_chars(10);
                        l.justify = Gtk.Justification.LEFT;
                        l.halign = Gtk.Align.START;
                        l.set_label(bsx[i]);
                        boxlabel += l;
                        l.override_background_color(Gtk.StateFlags.NORMAL, colors[0]);
                        grid1.attach(l,0,i+2,1,1);
                    }
                    add_cmd(MSP.Cmds.BOX,null,0,&have_box);
                    break;

                    case MSP.Cmds.BOX:
                    if(have_box == false)
                    {
                        have_box = true;
                        uint16[] bv = (uint16[])raw;
                        for(var i = 0; i < nboxen; i++)
                        {
                            var k = 0;
                            for(var j = 0; j < 12; j++)
                            {
                                uint16 mask = (1 << j);
                                var c = new Gtk.CheckButton();
                                checks += c;
                                c.active = ((bv[i] & mask) == mask);
                                c.toggled.connect(() => {
                                        uint16[] sv = new uint16[nboxen];
                                        for(var ib = 0; ib < nboxen; ib++)
                                        {
                                            sv[ib] = 0;
                                            for(var jb = 0; jb < 12; jb++)
                                            {
                                                var kb = jb + ib * 12;
                                                if(checks[kb].active)
                                                    sv[ib] |= (1 << jb);
                                            }
                                        }
                                    s.send_command(MSP.Cmds.SET_BOX, sv, nboxen*2);
                                    });
                                if((j % 3)  == 0 && j != 0)
                                {
                                    k += 1;
                                    var s = new Gtk.Separator(Gtk.Orientation.VERTICAL);
                                    grid1.attach(s,k,i+2,1,1);
                                    k += 1;
                                }
                                else
                                    k += 1;
                                grid1.attach(c,k,i+2,1,1);
                            }
                        }
                    }
                    grid1.show_all();
                    xflag = 0;
                    tid = Timeout.add(100, () => {
                            s.send_command(MSP.Cmds.STATUS,null,0);
                            s.send_command(MSP.Cmds.RC,null,0);
                            return true;
                        });
                    break;

                    case MSP.Cmds.RC:
                    uint16[] rc = (uint16[])raw;
                    for(var i = 0; i < 8; i++)
                    {
                        double d = (double)rc[i];
                        d = (d-1000)/1000.0;
                        lvbar[i].set_text(rc[i].to_string());
                        lvbar[i].set_fraction(d);
                    }
                    break;

                    case MSP.Cmds.STATUS:
                    MSP_STATUS *s = (MSP_STATUS*)raw;
                    if(xflag != s.flag)
                    {
                        for(var j = 0; j < nboxen; j++)
                        {
                            uint32 mask = (1 << j);
                            if((s.flag & mask) != (xflag & mask))
                            {
                                int icol;
                                if ((s.flag & mask) == mask)
                                    icol = 1;
                                else
                                    icol = 0;
                                boxlabel[j].override_background_color(Gtk.StateFlags.NORMAL, colors[icol]);
                            }
                        }
                        xflag = s.flag;
                    }
                    break;
                }
            });

        try {
            string icon=null;
            icon = MWPUtils.find_conf_file("switchedit_icon.svg");
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
        var refbutton = builder.get_object ("button3") as Gtk.Button;
        var savebutton = builder.get_object ("button1") as Gtk.Button;
        refbutton.clicked.connect(() => {
                have_names = false;
                if(is_connected == true)
                {
//                    add_cmd(MSP.Cmds.PID,null,0, &have_names);
                }
            });

        savebutton.clicked.connect(() => {
                if(is_connected == true && have_names == true)
                {

                }
            });

        refbutton.set_sensitive(false);
        savebutton.set_sensitive(false);

        var closebutton = builder.get_object ("button2") as Gtk.Button;
        closebutton.clicked.connect(() => {
                Gtk.main_quit();
            });

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
                    if(tid > 0)
                        Source.remove(tid);
                    tid = 0;
                    xflag = 0;
                    s.close();
                    conbutton.set_label("Connect");
                    refbutton.set_sensitive(false);
                    savebutton.set_sensitive(false);
                    verslab.set_label("");
                    have_vers = false;
                    is_connected = false;
                    have_names = false;
                    have_box = false;
                    foreach (var l in lvbar)
                    {
                        l.set_text("0");
                        l.set_fraction(0.0);
                    }
                    foreach (var b in boxlabel)
                    {
                        b.destroy();
                    }
                    boxlabel=null;
                    nboxen = 0;
                    foreach(var c in checks)
                    {
                        c.destroy();
                    }
                    checks = null;
                }
                grid1.hide();
            });

        window.show_all();
        grid1.hide();
    }


    public void run()
    {
        Gtk.main();
    }


    public static int main (string[] args)
    {
        Gtk.init(ref args);
        SwitchEdit app = new SwitchEdit (args);
        app.run ();
        return 0;
    }
}
