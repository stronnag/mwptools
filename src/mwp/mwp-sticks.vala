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

using Gtk;

namespace Sticks {
	internal static double oldstyle = 0.5;
	Gtk.Button sbb = null;
	StickBox sb = null;
	Gtk.PopoverMenu pop;

	public void done() {
		if (sb != null) {
			if (sb.get_parent() != null) {
				Gis.overlay.remove_overlay(sb);
			}
			sb = null;
		}
		if (sbb != null) {
			if (sbb.get_parent() != null) {
				Gis.overlay.remove_overlay(sbb);
			}
			sbb = null;
		}
	}

	public void update(int a, int e, int r, int t) {
		if(sb != null && sb.get_parent() != null) {
			sb.update(a, e, r, t);
		}
	}

	public void create_sticks() {
		sbb = new Gtk.Button();
		sb = new Sticks.StickBox(360,180);
		var isbb = new Gtk.Image.from_icon_name("view-refresh");
		isbb.set_pixel_size(24);
		sbb.has_frame=true;
		sbb.set_child(isbb);
		sbb.clicked.connect(() => {
				Gis.overlay.remove_overlay(sbb);
				Gis.overlay.add_overlay(sb);
			});
		sbb.halign = Gtk.Align.END;
		sbb.valign = Gtk.Align.END;
		sbb.margin_bottom=20;
		sbb.margin_end=2;
		sbb.tooltip_text = "Show stick movement";

		var sbuilder = new Gtk.Builder.from_resource ("/org/stronnag/mwp/gzmenu.ui");
		var menu = sbuilder.get_object("stick-menu") as GLib.MenuModel;
		pop = new Gtk.PopoverMenu.from_model(menu);
		var dg = new GLib.SimpleActionGroup();
		var aq = new GLib.SimpleAction("hide",null);
		aq.activate.connect(() => {
				Gis.overlay.remove_overlay(sb);
				Gis.overlay.add_overlay(sbb);
			});
		sb.halign = Gtk.Align.END;
		sb.valign = Gtk.Align.END;
		dg.add_action(aq);
		sb.insert_action_group("stick", dg);
		pop.set_parent(sb);

		var sbgestc = new Gtk.GestureClick();
		sb.add_controller(sbgestc);
		sbgestc.set_button(3);
		sbgestc.released.connect((n,x,y) => {
				Gdk.Rectangle rect = { (int)x, (int)y, 1, 1};
				pop.set_pointing_to(rect);
				pop.popup();
			});

		if(Mwp.conf.show_sticks == 0) {
			Gis.overlay.add_overlay(sb);
		} else {
			Gis.overlay.add_overlay(sbb);
		}
	}

	public class StickBox : Gtk.Box {
        public bool active;
        public Sticks.Pad lstick;
        public Sticks.Pad rstick;

        public StickBox(int w, int h) {
			bool rcstyle = Mwp.vi.fc_vers < Mwp.FCVERS.hasRCDATA;
			oldstyle = (rcstyle) ? 0.5 : 0.0;

			Object(orientation: Gtk.Orientation.HORIZONTAL);
			width_request = w;
			height_request = h;
			lstick = new Sticks.Pad (1000, 1500, false);
            append(lstick);
            rstick = new Sticks.Pad (1500,1500, true);
            append(rstick);
		}

        public void update(int a, int e, int r, int t) {
            lstick.update(t, r);
            rstick.update(e, a);
        }
    }

    public class Pad : Gtk.Widget {
        private double _x;
        private double _y;
        private double _hs;
        private double _vs;
        private bool _rside;

        public Pad (int ivs, int ihs, bool rside = false) {
            _vs = ivs;
            _hs = ihs;
            _rside = rside;
            hexpand = true;
            vexpand = true;
            set_opacity (1.0);
            queue_draw();
        }

		public override void snapshot (Gtk.Snapshot snap) {
			_x = get_width();
			_y = get_height();
			var rect = Graphene.Rect.zero();
			rect.init(0, 0, (float)_x, (float)_y);
			var cr = snap.append_cairo(rect);
			draw_base(cr);
			draw_dynamic(cr);
		}

        private const int LW=4;
        private const int CRAD=10;
        private const double OFFSET = 0.1;
        private const double SCALE = 0.8;

        private void draw_base(Cairo.Context cr) {
            double x = _x;
            double y = _y;

			// outer box
            cr.set_source_rgba (0.4, 0.4, 0.4, 0.5);
            cr.rectangle(0, 0, x, y);
            cr.fill();

            cr.set_source_rgba (0.1, 0.1, 0.1, 0.2); // inner box
            cr.rectangle(x*OFFSET, y*OFFSET, x*SCALE, y*SCALE);
            cr.fill();

            cr.set_line_width(LW);

            cr.move_to(x*0.5, y*OFFSET);
            cr.set_source_rgba (0.8, 0.8, 0.8, 0.8);
            cr.line_to(x*0.5, y*(OFFSET+SCALE));
            cr.stroke();

            cr.move_to(OFFSET*x, y/2);
            cr.line_to(x*(OFFSET+SCALE), y/2);
            cr.stroke();
        }

        private void draw_dynamic (Cairo.Context cr) {
            double sx, sy;
            sx = _hs - 1000;
            sx = _x*OFFSET + SCALE*_x*(sx / 1000.0);
            sy = 2000.0 - _vs;
            sy = OFFSET*_y + SCALE*_y*(sy / 1000.0);

            // draw blob and text
			cr.set_source_rgba (1, 0, 0, 0.5);
            cr.arc (sx, sy, CRAD, 0, 2 * Math.PI);
            cr.fill();
            cr.stroke();

            cr.set_font_size (0.042 * _x);
            cr.set_source_rgb (1, 1, 1);
            if (_rside == false)
                cr.move_to (0, _y/2);
            else
                cr.move_to (0.9*_x, _y/2);

            cr.show_text ("%4.0f".printf(_hs));
            cr.move_to (_x/2, 0.95*_y);
            cr.show_text ("%4.0f".printf(_vs));
            cr.stroke ();
        }

        public void update(double vs, double hs) {
            _vs = vs;
            _hs = hs;
            queue_draw();
        }
    }
}
