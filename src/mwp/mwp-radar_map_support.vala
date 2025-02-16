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
	private Gdk.Pixbuf [,] yplanes;
	private Gdk.Pixbuf [] rplanes;
	private Gdk.Pixbuf inavradar;
	private Gdk.Pixbuf inavtelem;
	private bool use_labels;
	public unowned MWPMarker? find_radar_item(uint rid) {
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
		use_labels = (Environment.get_variable("MWP_ADSB_LABEL") != null);
		CatMap.init();
		yplanes = new Gdk.Pixbuf[CatMap.MAXICONS, 25];
		try {
			inavradar = Img.load_image_from_file("inav-radar.svg");
			inavtelem = Img.load_image_from_file("inav-telem.svg");

			for(var i = 0; i < CatMap.MAXICONS; i++) {
				var bn = CatMap.name_for_index(i);
				var ys = "adsb/%s.svg".printf(bn);
				string xml;
				try {
					var fn = MWPUtils.find_conf_file(ys, "pixmaps");
					if (FileUtils.get_contents(fn, out xml)) {
						var doc = SVGReader.parse_svg(xml);
						for(int alt = 0; alt <= 12000; alt += 500) {
							int ia = alt/500;
							var bgfill =  SVGReader.rgb_for_alt((double)alt);
							var fgcol = (ia > 13) ? "#ffffff" : "#000000";
							var ypix = SVGReader.rewrite_svg(doc, bgfill, fgcol);
							yplanes[i, ia] = ypix;
						}
						var rpix = SVGReader.rewrite_svg(doc, "#ff0000", "#ffff00");
						rplanes += rpix;
						delete doc;
						Xml.Parser.cleanup();
					}
				} catch (Error e) {
					stderr.printf("Read %s %s\n", ys, e.message);
				}
			}
		} catch {
			MWPLog.message("Radar: Failed to load icons\n");
			Mwp.window.close();
		}
	}

	public void update_marker(uint rk) {
		var r = Radar.radar_cache.lookup(rk);
		if (r == null) {
			MWPLog.message(":BUG: Failed to find %x\n", rk);
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
					int ia = int.min( (int)r.altitude, 12499);
					if (ia < 0)
						ia = 0;
					uint iax = (uint)ia/500;
					r.lastiax = iax;
					img = yplanes[cdsc.idx, iax];
				}
			}
			if(use_labels) {
				rp = new MWPLabel(r.name);
			} else {
				rp  = new MWPMarker.from_image(img);
			}
            rp.set_selectable(false);
			rp.no = (int)rk;
			rp.has_tooltip = true;
			Gis.rm_layer.add_marker(rp);
			rp.query_tooltip.connect((x,y,k,t) => {
					var ri = Radar.radar_cache.lookup(rp.no);
					if (ri != null) {
						var s = generate_tt(ri);
						t.set_text(s);
						return true;
					} else {
						return false;
					}
				});
		}
		rp.opacity = (r.state == Radar.Status.STALE) ? 0.5 : 0.8;
		if (use_labels) {
			var ls = (r.state == Radar.Status.STALE) ? "Stale" : "(%d)".printf(r.state);
			var l = "%s\n%2d : %s".printf(r.name, r.lq, ls);
			((MWPLabel)rp).set_font_scale(0.9);
			((MWPLabel)rp).set_text(l);
		}
		r.lastdraw = new DateTime.now_local();
        rp.set_location (r.latitude, r.longitude);
		rp.visible = (r.state != Radar.Status.HIDDEN);
		if ((r.source & RadarSource.M_ADSB) != 0) {
			if(!use_labels) {
				var cdsc = CatMap.name_for_category(r.etype);
				if((r.alert & RadarAlert.SET) == RadarAlert.SET && (r.alert & RadarAlert.ALERT) != 0 &&  (Radar.astat & Radar.AStatus.A_RED) == Radar.AStatus.A_RED) {
					rp.set_image(rplanes[cdsc.idx]);
					r.lastiax = -1;
				} else if ((r.alert & RadarAlert.ALERT) == 0) {
					int ia = int.min( (int)r.altitude, 12499);
					if (ia < 0)
						ia = 0;
					uint iax = (int)ia/500;
					if (r.alert == RadarAlert.SET) {
						rp.set_image(yplanes[cdsc.idx, iax]);
						r.lastiax = iax;
					} else if (r.lastiax != iax) {
						rp.set_image(yplanes[cdsc.idx, iax]);
						r.lastiax = iax;
					}
				}
			}
			r.alert &= ~RadarAlert.SET;
			Radar.radar_cache.upsert(rk, r);
		}
		if(r.etype != 10 && !use_labels) {
			rp.rotate(r.heading);
		}
    }

	private string generate_tt(RadarPlot r) {
		string ga_alt;
		string ga_speed;
		string state;
		string xstate;
		string rng = "";
		if((r.source & RadarSource.M_ADSB) != 0) {
			ga_alt = Units.ga_alt(r.altitude);
			ga_speed = Units.ga_speed(r.speed);
			state = "(%s)".printf(CatMap.to_category(r.etype));
			xstate = ((RadarSource)r.source).to_string();
			rng = "\u2b80%s".printf(Radar.format_range(r));
		} else {
			ga_alt = "%.0f %s".printf(Units.distance(r.altitude), Units.distance_units());
			ga_speed = "%.0f %s".printf(Units.speed(r.speed), Units.speed_units());
			state = "(B6)";
			xstate = RadarView.status[r.state];
		}
		var tt = "%s / %s %s\n%s %s\n%s %s %.0f° %s".printf(
			r.name, xstate, state,
			PosFormat.lat(r.latitude, Mwp.conf.dms),
			PosFormat.lon(r.longitude, Mwp.conf.dms),
			ga_alt, ga_speed, r.heading, rng);
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