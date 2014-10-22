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

public class MWChooser : GLib.Object
{
    public enum MWVAR
    {
        UNDEF=0,
        MWOLD=1,
        MWNEW=2,
        BF=3,
        CF=4,
        INVALID1=5,
        INVALID2=6,
	AUTO=42
    }

    private Gtk.Dialog dialog;
    private Gtk.RadioButton [] btn = {};

    public static const string[]mwnames = { "","MW","MWNAV","BF","CF"};

    public static MWVAR fc_from_arg0()
    {
        var arg0 = Environment.get_application_name();
        string []parts;
        MWVAR mwvar = MWVAR.UNDEF;
        parts = arg0.split ("-");
        if(parts.length == 2)
        {
            mwvar = fc_from_name(parts[1]);
            if(mwvar != MWChooser.MWVAR.UNDEF)
                Environment.set_application_name(parts[0]);
        }
        return mwvar;
    }

    public static MWVAR fc_from_name(string name)
    {
        MWVAR mwvar;
        switch(name)
        {
            case "mw":
                mwvar = MWVAR.MWOLD;
                break;
            case "mwnav":
                mwvar = MWVAR.MWNEW;
                break;
            case "bf":
                mwvar = MWVAR.BF;
                break;
            case "cf":
                mwvar = MWVAR.CF;
                break;
            case "auto":
                mwvar = MWVAR.AUTO;
                break;
            default:
                mwvar = MWVAR.UNDEF;
            break;
        }
        return mwvar;
    }

    public MWChooser(Gtk.Builder builder)
    {
        dialog = builder.get_object ("mwchooser") as Gtk.Dialog;
        for(var j = 0; ; j++)
        {
            var s = "radiobutton%d".printf(j+1);
            var b = builder.get_object (s) as Gtk.RadioButton;
            if (b == null)
                break;
            else
                btn += b;
        }
    }

    public MWVAR get_version(MWVAR last)
    {
        int j;
        uint8 idx;
        MWVAR mw;

        idx = (uint8)last-1;
        if(idx >= btn.length)
            idx = (uint8)btn.length-1;
        btn[idx].set_active(true);
        dialog.show_all();
        dialog.run();
        for(j = 0; j < btn.length; j++)
        {
            if(btn[j].get_active())
                break;
        }
        switch(j)
        {
            case 0:
                mw = MWVAR.MWOLD;
                break;
            case 1:
                mw = MWVAR.MWNEW;
                break;
            case 2:
                mw = MWVAR.BF;
                break;
            case 3:
                mw = MWVAR.CF;
                break;
            default:
                mw = MWVAR.UNDEF;
                break;
        }
        dialog.hide();
        return mw;
    }
}
