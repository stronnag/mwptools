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

namespace Radar {

	private Gdk.Pixbuf [] yplanes;
	private Gdk.Pixbuf [] rplanes;
	private Gdk.Pixbuf inavradar;
	private Gdk.Pixbuf inavtelem;

	private unowned MWPMarker? find_radar_item(uint rid) {
		 var rdrlist =  Gis.rm_layer.get_markers();
		 for (unowned GLib.List<weak Shumate.Marker> lp = rdrlist.first();
			  lp != null; lp = lp.next) {
			 unowned MWPMarker m = lp.data as MWPMarker;
			 if (m.no == rid) {
				 return m;
			 }
		 }
		 return null;
	}

	public void init_icons() {
		CatMap.init();
		try {
			inavradar = Img.load_image_from_file("inav-radar.svg",
												 Mwp.conf.misciconsize,Mwp.conf.misciconsize);
			inavtelem = Img.load_image_from_file("inav-telem.svg",
												 Mwp.conf.misciconsize,Mwp.conf.misciconsize);

			for(var i = 0; i < CatMap.MAXICONS; i++) {
				var bn = CatMap.name_for_index(i);
				var ys = "adsb/%s.svg".printf(bn);
				var rs = "adsb/%s_red.svg".printf(bn);
				yplanes += Img.load_image_from_file(ys, -1, -1);
				rplanes += Img.load_image_from_file(rs, -1, -1);
			}
		} catch {
			MWPLog.message("Radar: Failed to load icons\n");
			Mwp.window.close();
		}
	}

	public void update_marker(uint rk) {
		var r = Radar.radar_cache.lookup(rk);
		if (r == null) {
			return;
		}
		var rp = find_radar_item(rk);
		if(rp == null) {
			Gdk.Pixbuf img=null;
			if (r.source == RadarSource.INAV) {
				img = inavradar;
            } else if (r.source == RadarSource.TELEM) {
				img = inavtelem;
			} else {
				var cdsc = CatMap.name_for_category(r.etype);
				if((r.alert & RadarAlert.ALERT) != 0 && (Radar.astat & Radar.AStatus.A_RED) == Radar.AStatus.A_RED) {
					img = rplanes[cdsc.idx];
				} else {
					img = yplanes[cdsc.idx];
				}
			}
			rp  = new MWPMarker.from_image(img);
            rp.set_selectable(false);
			rp.no = (int)rk;
			rp.opacity = 0.8;
			Gis.rm_layer.add_marker (rp);
			rp.has_tooltip = true;
			rp.query_tooltip.connect((x,y,k,t) => {
					var ri = Radar.radar_cache.lookup(rp.no);
					var s = generate_tt(ri);
					t.set_text(s);
					return true;
				});
		}
        rp.set_location (r.latitude, r.longitude);
		if ((r.source & RadarSource.M_ADSB) != 0) {
			if((r.alert & RadarAlert.SET) == RadarAlert.SET) {
				var cdsc = CatMap.name_for_category(r.etype);
				if((r.alert & RadarAlert.ALERT) != 0 &&  (Radar.astat & Radar.AStatus.A_RED) == Radar.AStatus.A_RED) {
					rp.set_image(rplanes[cdsc.idx]);
				} else if (r.alert == RadarAlert.SET) {
					rp.set_image(yplanes[cdsc.idx]);
				}
				r.alert &= ~RadarAlert.SET;
				Radar.radar_cache.upsert(rk, r);
			}
		}
		if(r.etype != 10) {
			rp.rotate(r.heading);
		}
    }

	private string generate_tt(RadarPlot r) {
		string ga_alt;
		string ga_speed;
		string state;
		string xstate;
		if((r.source & RadarSource.M_ADSB) != 0) {
			ga_alt = Units.ga_alt(r.altitude);
			ga_speed = Units.ga_speed(r.speed);
			state = "(%s)".printf(CatMap.to_category(r.etype));
			xstate = ((RadarSource)r.source).to_string();
		} else {
			ga_alt = "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units());
			ga_speed = "%.0f %s".printf(Units.speed(r.speed), Units.speed_units());
			state = "(B6)";
			xstate = RadarView.status[r.state];
		}
		var tt = "%s / %s %s\n%s %s\n%s %s %.0f° ".printf(
			r.name, xstate, state,
			PosFormat.lat(r.latitude, Mwp.conf.dms),
			PosFormat.lon(r.longitude, Mwp.conf.dms),
			ga_alt, ga_speed, r.heading);
		return tt;
	}

	public void set_radar_stale(uint rid) {
        var rp = find_radar_item(rid);
        if(rp != null) {
            rp.opacity = 0.5;
        }
    }

    public void remove_radar(uint rid) {
        var rp = find_radar_item(rid);
		Gis.rm_layer.remove_marker(rp);
	}

    public void set_radar_hidden(uint rid) {
        var rp = find_radar_item(rid) as MWPMarker;
        if(rp != null) {
			rp.visible=false;
        }
    }
}