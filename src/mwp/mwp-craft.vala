/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

/* Layer usage
   crpath     : craft movement (grey path, coloured dots)
   crlayer    : craft icon
   pmlayer  : special points (home, RTH, WP start)
*/

namespace Posring {
	private MWPPoint pt=null;
	public void init() {
		pt = new MWPPoint.with_colour(Mwp.conf.wp_spotlight, 0);
		pt.set_size_request(60, 60);
		Gis.info_layer.add_marker (pt);
		pt.hide();
	}
	public void set_location (double lat, double lon) {
		if(pt == null) {
			init();
		}
		pt.set_location (lat,lon);
		pt.show();
	}
	public void hide() {
		if(pt == null) {
			init();
		}
		pt.hide();
	}
}

public const string PREVIEW_IMG = "default-model.svg";
public class Craft : Object {
	private MWPMarker cricon;
	private Shumate.MarkerLayer crlayer;
	private bool trail;
	private Shumate.PathLayer   crpath;
	private Shumate.MarkerLayer pmlayer;
	private int npath = 0;
	private int mpath = 0;
	private const string trk_cyan    = "#00ffffa0";
	private const string trk_green   = "#ceff9da0";
	private const string trk_yellow  = "#ffff00a0";
	private const string trk_white   = "#ffffffa0";
	private const string trk_altblue = "#03c0faa0";
	private const string trk_purple  = "#bf88f7a0";
	private const string trk_orange  = "#ff8000a0";
	private const string trk_pink    = "#ff92f0a0";
	private string path_colour;

	private MWPLabel posp ;
	private MWPLabel rthp ;
	private MWPLabel wpp ;
	private int stack_size = 0;
	private int mod_points = 0;
	private bool moving_map;

    public enum Special {
        HOME = -1,
        PH = -2,
        RTH = -3,
        WP = -4,
        ALTH = -5,
        CRUISE = -6,
        UNDEF = -7,
		LAND = -8,
    }

    public enum RMIcon {
        PH = 1,
        RTH = 2,
        WP = 4,
        ALL = 0xff
    }


	public Craft (string img=PREVIEW_IMG) {
		cricon = new MWPMarker.from_image_file(img, 40);
		path_colour = trk_cyan;
        IconTools.Hexcol ladyjane = {0xa0, 0xa0, 0xa0, 0xa0}; //grey (of course)
        pmlayer = new Shumate.MarkerLayer(Gis.map.viewport);
        crpath = new Shumate.PathLayer(Gis.map.viewport);
        crlayer = new Shumate.MarkerLayer(Gis.map.viewport);
        crpath.set_stroke_color(ladyjane.to_rbga());
        crpath.set_stroke_width (4);

		Gis.map.insert_layer_above (crpath, Gis.hp_layer); // above home layer
		Gis.map.insert_layer_above (crlayer, Gis.hm_layer); // above home layer
		Gis.map.insert_layer_above (pmlayer, Gis.mp_layer); // above mission path layer
        posp = rthp = wpp = null;
		crlayer.add_marker (cricon);
        park();
		moving_map = (Environment.get_variable("MMAP") != null);
	}

    public void new_craft (bool _trail = false, int _stack = 0, int _modulop = 0) {
        trail = _trail;
        stack_size = _stack;
        mod_points = _modulop;
		init_trail();
		cricon.show();
	}

    public void init_trail() {
		var nds = pmlayer.get_markers();
		if (nds.length() != 0) {
			pmlayer.remove_all();
			crpath.remove_all();
		}
		npath = 0;
		mpath = 0;
		posp = rthp = wpp = null;
	}

    public void remove_marker() {
        park();
    }

    public void remove_all() {
		init_trail();
        park();
    }

    public void park() {
        cricon.hide();
    }

    public void get_pos(out double lat, out double lon) {
        lat = cricon.get_latitude();
        lon = cricon.get_longitude();
    }

    public void set_lat_lon (double lat, double lon, double cse) {
		if (!cricon.visible)
			cricon.show();

		if(trail) {
			var marker = new MWPPoint.with_colour(path_colour, 0);
			marker.set_size_request(8,8);
            marker.set_location (lat,lon);

			if(mod_points == 0 || (npath % mod_points) == 0) {
                pmlayer.add_marker(marker);
                if(stack_size > 0) {
                    mpath++;
                    if(mpath > stack_size) {
                        var nds = pmlayer.get_markers();
                        pmlayer.remove_marker(nds.last().data);
                        mpath--;
                    }
                }
            }
			//crpath.add_node(marker);
			npath++;
        }
		cricon.set_location (lat, lon);
		if(Mwp.conf.view_mode == 2) {
			cricon.rotate(0);
			var hdr = (360 - cse) % 360;
			Gis.map.viewport.rotation = hdr*Math.PI/180.0;
		} else {
			cricon.rotate(cse);
		}
    }

    public void set_normal() {
        remove_special(RMIcon.ALL);
    }

    public void remove_special(RMIcon rmflags) {
        if(((rmflags & RMIcon.PH) != 0) && posp != null) {
            pmlayer.remove_marker(posp);
            posp = null;
        }
        if(((rmflags & RMIcon.RTH) != 0) && rthp != null) {
            pmlayer.remove_marker(rthp);
            rthp = null;
        }
        if(((rmflags & RMIcon.WP) != 0) && wpp != null) {
            pmlayer.remove_marker(wpp);
            wpp = null;
        }
        if(rmflags == RMIcon.ALL)
            path_colour = trk_cyan;
    }

    public void special_wp(Special wpno, double lat, double lon) {
        MWPLabel? m = null;
        RMIcon rmflags = 0;
        switch(wpno) {
            case Special.HOME:
				HomePoint.set_home(lat, lon);
                break;
            case Special.PH:
                if(posp == null) {
                    posp = new MWPLabel("∞");
					posp.set_colour("#4cfe00c8");
					posp.set_text_colour("black");
                    pmlayer.add_marker(posp);
                }
                m = posp;
                rmflags = RMIcon.RTH|RMIcon.WP;
                path_colour = trk_green;
                break;
            case Special.RTH:
                if(rthp == null) {
					rthp = new MWPLabel("⚑");
					rthp.set_colour ("#fafa00c8");
                    rthp.set_text_colour("black");
                    pmlayer.add_marker(rthp);
                }
                m = rthp;
                rmflags = RMIcon.PH|RMIcon.WP;
                path_colour = trk_yellow;
                break;
            case Special.WP:
                if(wpp == null) {
                    wpp = new MWPLabel("☛");
                    wpp.set_colour ("white");
                    wpp.set_text_colour("black");
                    pmlayer.add_marker(wpp);
                }
                m = wpp;
                rmflags = RMIcon.PH|RMIcon.RTH;
                path_colour = trk_white;
                break;
            case Special.ALTH:
                path_colour = trk_altblue;
				rmflags = RMIcon.PH|RMIcon.RTH|RMIcon.WP;
                break;
            case Special.CRUISE:
                path_colour = trk_purple;
				rmflags = RMIcon.PH|RMIcon.RTH|RMIcon.WP;
                break;
            case Special.LAND:
                path_colour = trk_pink;
				rmflags = RMIcon.PH|RMIcon.RTH|RMIcon.WP;
                break;
            case Special.UNDEF:
                path_colour = trk_orange;
                rmflags = RMIcon.PH|RMIcon.RTH|RMIcon.WP;
                break;
            default:
                path_colour = trk_cyan;
                rmflags = RMIcon.ALL;
                break;
        }
		if(rmflags != 0)
            remove_special(rmflags);
        if(m != null)
            m.set_location (lat, lon);
    }
}
