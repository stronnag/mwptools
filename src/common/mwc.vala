/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
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

public class MWChooser : GLib.Object {
    public enum MWVAR {
        UNDEF=0,
        MWOLD=1,
        MWNEW=2,
        CF=3,
        INAV=4,
		AUTO=42
    }

    public static MWVAR fc_from_name(string name) {
        MWVAR mwvar;
        switch(name) {
            case "mw":
                mwvar = MWVAR.MWOLD;
                break;
            case "mwnav":
                mwvar = MWVAR.MWNEW;
                break;
            case "cf":
            case "bf":
                mwvar = MWVAR.CF;
                break;
            case "inav":
                mwvar = MWVAR.INAV;
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
}
