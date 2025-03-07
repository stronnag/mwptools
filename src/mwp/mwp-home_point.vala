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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace HomePoint {
	public enum User {
		NONE = 0,
		MISSIONEDIT = 1,
	}

	public MWPLabel? hp =null;
	public User user = User.NONE;


	public bool is_valid() {
		return 	(hp != null && hp.visible);
	}

	public bool hidden() {
		return !is_valid();
	}

	public void try_hide() {
		/*if (MissionManager.mdx == -1)*/ {
			if(hp != null)
				hp.visible=false;
		}
	}

	public double lat() {
		return hp.latitude;
	}

	public double lon() {
		return hp.longitude;
	}

	public bool get_location(out double lat, out double lon) {
		if(is_valid()) {
			lat = hp.latitude;
			lon = hp.longitude;
			return true;
		} else {
			lat = lon = 0.0;
			return false;
		}
	}

	public bool get_elevation(out double alt) {
		if(is_valid()) {
			alt = DemManager.lookup(hp.latitude, hp.longitude);
			return true;
		} else {
			alt = 0.0;
			return false;
		}
	}

	public void set_home(double lat, double lon) {
		if (hp == null) {
			var symb = "⏏"; // \u23cf
			string hcol = "#8c4343%02x".printf(Mwp.conf.mission_icon_alpha);
			hp = new MWPLabel(symb);
 			hp.set_colour(hcol);
			hp.set_text_colour("white");
			hp.no = 256;
			hp.set_draggable(true);

			Gis.hm_layer.add_marker(hp);
			hp.drag_motion.connect((la, lo) => {
					set_htt(la, lo);
				});
		}
		hp.visible=true;
		hp.set_location (lat, lon);
		set_htt(lat, lon);
	}

	private void set_htt(double la, double lo) {
		var htt = PosFormat.pos(la, lo, Mwp.conf.dms, true);
		hp.set_tooltip_text("Home\n%s".printf(htt));
	}
}
