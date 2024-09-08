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
		 unowned MWPMarker rd = null;
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
				if ((r.alert & RadarAlert.ALERT) == RadarAlert.ALERT) {
					img = rplanes[cdsc.idx];
				} else {
					img = yplanes[cdsc.idx];
				}
			}
			rp  = new MWPMarker.from_image(img);
			rp.extra = new MWPLabel();
			Gis.tt_layer.add_marker((MWPLabel)rp.extra);
			rp.extra.hide();
			uint tt_timer = 0;

			rp.leave.connect(() => {
					if(tt_timer != 0) {
						Source.remove(tt_timer);
						tt_timer = 0;
					}
					rp.extra.hide();
				});
			rp.enter.connect((x,y) => {
					rp.extra.show();
					tt_timer = Timeout.add_seconds_once(30, () => {
							tt_timer = 0;
							rp.extra.hide();
						});
				});
            rp.set_selectable(false);
			rp.no = (int)rk;
			rp.opacity = 0.8;
			Gis.rm_layer.add_marker (rp);
		}
        rp.set_location (r.latitude, r.longitude);
		if ((r.source & RadarSource.M_ADSB) != 0) {
			if((r.alert & RadarAlert.SET) == RadarAlert.SET) {
				var cdsc = CatMap.name_for_category(r.etype);
				if((r.alert & RadarAlert.ALERT) == RadarAlert.ALERT) {
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
		var tt = generate_tt(r);
		((MWPLabel)rp.extra).set_text(tt);
		var l = ((MWPLabel)rp.extra).get_child();
		var _h = l.get_height();
		var _w = l.get_width();
		if (_w == 0) _w = 100;
		if (_h == 0) _h = 50;
		double _sx,_sy;
		Gis.map.viewport.location_to_widget_coords(Gis.map, rp.latitude, rp.longitude,
												   out _sx, out _sy);
		double tla, tlo;
		Gis.map.viewport.widget_coords_to_location (Gis.map,
													_sx+10+(_w+1.0)/2.0, _sy+10+(_h+1)/2,
													out tla, out tlo);
		((MWPLabel)rp.extra).latitude = tla;
		((MWPLabel)rp.extra).longitude = tlo;
    }

	private string generate_tt(RadarPlot r) {
		string ga_alt;
		string ga_speed;
		string state;
		if((r.source & RadarSource.M_ADSB) != 0) {
			ga_alt = Units.ga_alt(r.altitude);
			ga_speed = Units.ga_speed(r.speed);
			state = "(%s)".printf(CatMap.to_category(r.etype));
		} else {
			ga_alt = "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units());
			ga_speed = "%.0f %s".printf(Units.speed(r.speed), Units.speed_units());
			state = "";
		}
		var tt = "%s / %s %s\n%s %s\n%s %s %.0f° ".printf(
			r.name, RadarView.status[r.state], state,
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
		if(rp != null) {
			if(rp.extra != null) {
				Gis.tt_layer.remove_marker((Shumate.Marker)rp.extra);
			}
			Gis.rm_layer.remove_marker(rp);
		}
	}

    public void set_radar_hidden(uint rid) {
        var rp = find_radar_item(rid) as MWPMarker;
        if(rp != null) {
			rp.hide();
        }
    }
}