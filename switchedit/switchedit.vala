
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
    private uint32 xflag = -1;
    private Gdk.RGBA[] colors;
    private uint tid;
    private string lastfile;

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

    private void get_settings(out string[] devs, out uint baudrate)
    {
        devs={};
        baudrate=0;
        Settings settings = null;
        var sname = "org.mwptools.planner";
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
            baudrate = settings.get_uint("baudrate");
        }
    }

    private void apply_state()
    {
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
                    add_boxlabels(bsx);
                    add_cmd(MSP.Cmds.BOX,null,0,&have_box);
                    break;

                    case MSP.Cmds.BOX:
                    if(have_box == false)
                    {
                        have_box = true;
                        add_switch_states((uint16[])raw);
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
        uint baudrate;
        get_settings(out devs, out baudrate);
        foreach(string a in devs)
        {
            dentry.append_text(a);
        }

        var te = dentry.get_child() as Gtk.Entry;
        te.can_focus = true;
        dentry.active = 0;

        verslab = builder.get_object ("verslab") as Gtk.Label;
        verslab.set_label("");

        var saveasbutton = builder.get_object ("button5") as Gtk.Button;
        saveasbutton.clicked.connect(() => {
                save_file();
            });
        saveasbutton.set_sensitive(false);

        var openbutton = builder.get_object ("button3") as Gtk.Button;
        openbutton.clicked.connect(() => {
                load_file();
                saveasbutton.set_sensitive(true);
            });

        var applybutton = builder.get_object ("button1") as Gtk.Button;
        applybutton.clicked.connect(() => {
                if(is_connected == true && have_names == true)
                {
                    apply_state();
                    s.send_command(MSP.Cmds.EEPROM_WRITE,null, 0);
                }
            });
        applybutton.set_sensitive(false);

        var closebutton = builder.get_object ("button2") as Gtk.Button;
        closebutton.clicked.connect(() => {
                Gtk.main_quit();
            });

        conbutton.clicked.connect(() => {
                string estr;
                if (is_connected == false)
                {
                    serdev = dentry.get_active_text();
                    if(s.open(serdev,baudrate, out estr) == true)
                    {
                        is_connected = true;
                        conbutton.set_label("Disconnect");
                        applybutton.set_sensitive(true);
                        saveasbutton.set_sensitive(true);
                        add_cmd(MSP.Cmds.IDENT,null,0,&have_vers);
                    }
                    else
                    {
                        stderr.printf("open failed %s %s\n", serdev, estr);
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
                    applybutton.set_sensitive(false);
                    saveasbutton.set_sensitive(false);
                    verslab.set_label("");
                    cleanupui();
                }
                grid1.hide();
            });

        window.show_all();
        grid1.hide();
    }

    private void cleanupui()
    {

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
        boxlabel={};
        nboxen = 0;
        foreach(var c in checks)
        {
            c.destroy();
        }
        checks = {};
        grid1.hide();
    }

    private void add_boxlabels(string[]bsx)
    {
        boxlabel={};
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
    }

    private void add_switch_states(uint16[] bv)
    {
        checks={};
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
                        apply_state();
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

    private void save_file()
    {
        var chooser = new Gtk.FileChooserDialog (
            "Save switches", window,
            Gtk.FileChooserAction.SAVE,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Save",  Gtk.ResponseType.ACCEPT);

        if(lastfile == null)
        {
            chooser.set_current_name("untitled-switches.json");
        }
        else
        {
            chooser.set_filename(lastfile);
        }

        if (chooser.run () == Gtk.ResponseType.ACCEPT)
        {
            lastfile = chooser.get_filename();
            save_data();
        }
        chooser.close ();
    }

    private void load_file()
    {
        var chooser = new Gtk.FileChooserDialog (
            "Load switch file", window, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);

        Gtk.FileFilter filter = new Gtk.FileFilter ();
        filter.set_filter_name ("JSON switch files");
        filter.add_pattern ("*.json");
        chooser.add_filter (filter);
        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);

        string fn = null;
        if (chooser.run () == Gtk.ResponseType.ACCEPT) {
            fn= chooser.get_filename();
        }
        chooser.close ();

        if(fn != null)
        {
            lastfile = fn;
            if(nboxen != 0)
            {
                var x_have_vers = have_vers;
                var x_is_connected = is_connected;
                cleanupui();
                have_vers = x_have_vers;
                is_connected = x_is_connected;
            }

            try
            {
                var parser = new Json.Parser ();
                parser.load_from_file (lastfile );
                var root_object = parser.get_root ().get_object ();
                var arry = root_object.get_array_member ("switches");
                nboxen = arry.get_length ();
                string[] bsx = new string[nboxen];
                uint16[] bv = new uint16[nboxen];
                var r = 0;
                foreach (var node in arry.get_elements ())
                {
                    uint16 sval = 0;
                    var item = node.get_object ();
                    bsx[r]= item.get_string_member("name");
                    string str = item.get_string_member ("value");
                    int j = 0;
                    foreach (var b in str.data)
                    {
                        switch(b)
                        {
                            case 'X':
                                sval |= (1 << j);
                                j++;
                                break;
                            case '_':
                                j++;
                                break;
                        }
                    }
                    bv[r] = sval;
                    r++;
                }
                add_boxlabels(bsx);
                add_switch_states(bv);
                grid1.show_all();
                xflag = 0;
                have_names = true;
                have_box = true;
            } catch (Error e) {
                stderr.printf ("Failed to parse file\n");
            }
        }
    }

    private void save_data()
    {
        Json.Generator gen;
        gen = new Json.Generator ();
        Json.Builder builder = new Json.Builder ();
        builder.begin_object ();

        builder.set_member_name ("multiwii");
        builder.add_string_value ("2.3");

        builder.set_member_name ("date");
        var dt = new DateTime.now_utc();
	builder.add_string_value (dt.to_string());

        builder.set_member_name ("switches");
        builder.begin_array ();
        var idx=0;
        for(var r = 0; r < nboxen; r++)
        {
             builder.begin_object ();
             builder.set_member_name ("id");
             builder.add_int_value (r);
             builder.set_member_name ("name");
             builder.add_string_value (boxlabel[r].get_label());
             builder.set_member_name ("value");
             uint8 bstr[16];
             int i = 0;
             for(var j =  0; j < 12; j++)
             {
                  if(j > 0 && (j%3)==0)
                  {
                      bstr[i++]=' ';
                  }

                  if(checks[idx].active)
                  {
                      bstr[i++]='X';
                  }
                  else
                  {
                      bstr[i++]='_';
                  }
                  idx++;
             }
             builder.add_string_value ((string)bstr);
             builder.end_object ();
         }
         builder.end_array();
         builder.end_object ();
         Json.Node root = builder.get_root ();
         gen.set_pretty(true);
         gen.set_root (root);
         var json = gen.to_data(null);
         try{
             FileUtils.set_contents(lastfile,json);
         }catch(Error e){
             stderr.printf ("Error: %s\n", e.message);
         }
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
