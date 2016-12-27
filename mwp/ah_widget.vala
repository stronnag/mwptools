using Gtk;

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
 * This module is derived from the following work:
 * Gtk Artificial Horizon Widget
 * Copyright (C) 2010, CCNY Robotics Lab
 * Gautier Dumonteil <gautier.dumonteil@gmail.com>
 * http://robotics.ccny.cuny.edu
 */

namespace Ath {

    public class Horizon : DrawingArea {

        private bool init = true;
        private double _x;
        private double _y;
        private double _radius;
        private double _trans_y = 0;
        private double _angle = 0;

        public Horizon () {
            init = true;
        }
        private void draw_base(Cairo.Context cr)
        {
            double rec_x0, rec_y0, rec_width, rec_height, rec_degrees;
            double rec_aspect, rec_corner_radius, rec_radius;
            double x = _x;
            double y = _y;
            double radius = _radius;
            rec_x0 = x - radius;
            rec_y0 = y - radius;
            rec_width = radius * 2;
            rec_height = radius * 2;
            rec_aspect = 1.0;
            rec_corner_radius = rec_height / 8.0;
            rec_radius = rec_corner_radius / rec_aspect;
            rec_degrees = Math.PI / 180.0;
            cr.new_sub_path();
            cr.arc(rec_x0 + rec_width - rec_radius, rec_y0 + rec_radius,
                    rec_radius, -90 * rec_degrees, 0 * rec_degrees);
            cr.arc(rec_x0 + rec_width - rec_radius, rec_y0 + rec_height - rec_radius,
                   rec_radius, 0 * rec_degrees, 90 * rec_degrees);
            cr.arc(rec_x0 + rec_radius, rec_y0 + rec_height - rec_radius,
                   rec_radius, 90 * rec_degrees, 180 * rec_degrees);
            cr.arc(rec_x0 + rec_radius, rec_y0 + rec_radius, rec_radius, 180 * rec_degrees, 270 * rec_degrees);
            cr.close_path ();

            cr.set_source_rgb (0.1, 0.1, 0.1);
            cr.fill_preserve ();
            cr.stroke ();

            cr.arc (x, y, radius, 0, 2 * Math.PI);
            cr.set_source_rgb (0, 0, 0);
            cr.fill_preserve ();
            cr.stroke ();

            cr.arc (x, y, radius - 0.04 * radius, 0, 2 * Math.PI);
            cr.set_source_rgb (0.6, 0.5, 0.5);
            cr.stroke ();
            _radius = 0.9*radius;
        }

        public override bool draw (Cairo.Context cr) {
            _x = get_allocated_width () / 2;
            _y = get_allocated_height () / 2;
            _radius = double.min (get_allocated_width () / 2,
                                     get_allocated_height () / 2) - 5;

            if(init)
                draw_base(cr);
            draw_dynamic(cr);
            return false;
        }

        private double deg2rad(double d)
        {
            return d*Math.PI/180.0;
        }

        private void draw_internal_sphere(Cairo.Context cr)
        {
            double x, y, radius;
            radius = _radius;
            x = _x;
            y = _y;

            cr.save();
            cr.translate(x, y);
            x = 0;
            y = (_trans_y * 0.134 * radius) / 10;
            cr.rotate(deg2rad(_angle));

  // **** internal sphere
            cr.arc (x, y, 2 * radius, Math.PI, 0);
            cr.set_source_rgb (0.117, 0.564, 1);
            cr.fill ();
            cr.stroke ();

            cr.arc (x, y, 2 * radius, 0, Math.PI);
            cr.set_source_rgb (0.651, 0.435, 0.098);
            cr.fill ();
            cr.stroke ();

            cr.set_line_width (0.02 * radius);
            cr.move_to (x - radius, y);
            cr.line_to (x + radius, y);
            cr.set_source_rgb (1, 1, 1);
            cr.stroke ();

  // **** horizontal line (pitch)
// **** horizontal line (pitch)
            cr.move_to (x - 0.4 * radius, y - 0.4 * radius);
            cr.line_to (x + 0.4 * radius, y - 0.4 * radius);
            cr.stroke ();
            cr.move_to (x - 0.3 * radius, y - 0.268 * radius);
            cr.line_to (x + 0.3 * radius, y - 0.268 * radius);
            cr.stroke ();
            cr.move_to (x - 0.2 * radius, y - 0.134 * radius);
            cr.line_to (x + 0.2 * radius, y - 0.134 * radius);
            cr.stroke ();
            cr.move_to (x - 0.1 * radius, y - 0.4 * radius + 0.067 * radius);
            cr.line_to (x + 0.1 * radius, y - 0.4 * radius + 0.067 * radius);
            cr.stroke ();
            cr.move_to (x - 0.1 * radius, y - 0.268 * radius + 0.067 * radius);
            cr.line_to (x + 0.1 * radius, y - 0.268 * radius + 0.067 * radius);
            cr.stroke ();
            cr.move_to (x - 0.1 * radius, y - 0.134 * radius + 0.067 * radius);
            cr.line_to (x + 0.1 * radius, y - 0.134 * radius + 0.067 * radius);
            cr.stroke ();

            cr.move_to (x - 0.4 * radius, y + 0.4 * radius);
            cr.line_to (x + 0.4 * radius, y + 0.4 * radius);
            cr.stroke ();
            cr.move_to (x - 0.3 * radius, y + 0.268 * radius);
            cr.line_to (x + 0.3 * radius, y + 0.268 * radius);
            cr.stroke ();
            cr.move_to (x - 0.2 * radius, y + 0.134 * radius);
            cr.line_to (x + 0.2 * radius, y + 0.134 * radius);
            cr.stroke ();
            cr.move_to (x - 0.1 * radius, y + 0.4 * radius - 0.067 * radius);
            cr.line_to (x + 0.1 * radius, y + 0.4 * radius - 0.067 * radius);
            cr.stroke ();
            cr.move_to (x - 0.1 * radius, y + 0.268 * radius - 0.067 * radius);
            cr.line_to (x + 0.1 * radius, y + 0.268 * radius - 0.067 * radius);
            cr.stroke ();
            cr.move_to (x - 0.1 * radius, y + 0.134 * radius - 0.067 * radius);
            cr.line_to (x + 0.1 * radius, y + 0.134 * radius - 0.067 * radius);
            cr.stroke ();

            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL,
                                 Cairo.FontWeight.NORMAL);

            cr.set_font_size (0.1 * radius);
            cr.move_to (x - 0.35 * radius, y - 0.1 * radius);
            cr.show_text ("10");
            cr.stroke ();
            cr.move_to (x + 0.21 * radius, y - 0.1 * radius);
            cr.show_text ("10");
            cr.stroke ();

            cr.move_to (x - 0.35 * radius, y + 0.17 * radius);
            cr.show_text ("10");
            cr.stroke ();
            cr.move_to (x + 0.21 * radius, y + 0.17 * radius);
            cr.show_text ("10");
            cr.stroke ();

            cr.move_to (x - 0.45 * radius, y - 0.234 * radius);
            cr.show_text ("20");
            cr.stroke ();
            cr.move_to (x + 0.31 * radius, y - 0.234 * radius);
            cr.show_text ("20");
            cr.stroke ();

            cr.move_to (x - 0.45 * radius, y + 0.302 * radius);
            cr.show_text ("20");
            cr.stroke ();
            cr.move_to (x + 0.31 * radius, y + 0.302 * radius);
            cr.show_text ("20");
            cr.stroke ();

            cr.move_to (x - 0.55 * radius, y - 0.368 * radius);
            cr.show_text ("30");
            cr.stroke ();
            cr.move_to (x + 0.41 * radius, y - 0.368 * radius);
            cr.show_text ("30");
            cr.stroke ();

            cr.move_to (x - 0.55 * radius, y + 0.434 * radius);
            cr.show_text ("30");
            cr.stroke ();
            cr.move_to (x + 0.41 * radius, y + 0.434 * radius);
            cr.show_text ("30");
            cr.stroke ();
            cr.restore ();
        }

        private void draw_external_arc (Cairo.Context cr)
        {
            double x, y, radius;
            radius = _radius;
            x = _x;
            y = _y;

            cr.save ();
            cr.translate (x, y);
            x = 0;
            y = 0;
            cr.rotate (deg2rad (_angle));

  // **** external demi arc sky
            cr.set_line_width (0.15 * radius);
            cr.arc (x, y, radius - 0.075 * radius, Math.PI, 0);
            cr.set_source_rgb (0.117, 0.564, 1);
            cr.stroke ();

  // **** external demi arc ground
            cr.arc (x, y, radius - 0.075 * radius, 0, Math.PI);
            cr.set_source_rgb (0.651, 0.435, 0.098);
            cr.stroke ();

                // **** external arc alpha composante
            cr.arc (x, y, radius - 0.075 * radius, 0, 2 * Math.PI);
            cr.set_source_rgba (0.3, 0.3, 0.3, 0.3);
            cr.stroke ();

            cr.set_line_width (0.04 * radius);
            cr.move_to (x - radius, y);
            cr.line_to (x - radius + 0.15 * radius, y);
            cr.set_source_rgb (1, 1, 1);
            cr.stroke ();
            cr.set_line_width (0.04 * radius);
            cr.move_to (x + radius, y);
            cr.line_to (x + radius - 0.15 * radius, y);
            cr.set_source_rgb (1, 1, 1);
            cr.stroke ();
                // **** external arc tips
            cr.set_line_width (0.02 * radius);
            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-Math.PI / 6),
                           y + (radius - 0.15 * radius) * Math.sin (-Math.PI / 6));
            cr.line_to (x + (radius - 0.04 * radius) * Math.cos (-Math.PI / 6),
                           y + (radius - 0.04 * radius) * Math.sin (-Math.PI / 6));
            cr.stroke ();

            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-2 * Math.PI / 6),
                           y + (radius - 0.15 * radius) * Math.sin (-2 * Math.PI / 6));
            cr.line_to (x + (radius - 0.04 * radius) * Math.cos (-2 * Math.PI / 6),
                           y + (radius - 0.04 * radius) * Math.sin (-2 * Math.PI / 6));
            cr.stroke ();

            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-4 * Math.PI / 6),
                           y + (radius - 0.15 * radius) * Math.sin (-4 * Math.PI / 6));
            cr.line_to (x + (radius - 0.04 * radius) * Math.cos (-4 * Math.PI / 6),
                           y + (radius - 0.04 * radius) * Math.sin (-4 * Math.PI / 6));
            cr.stroke ();

            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-5 * Math.PI / 6),
                           y + (radius - 0.15 * radius) * Math.sin (-5 * Math.PI / 6));
            cr.line_to (x + (radius - 0.04 * radius) * Math.cos (-5 * Math.PI / 6),
                           y + (radius - 0.04 * radius) * Math.sin (-5 * Math.PI / 6));
            cr.stroke ();

            cr.set_line_width (0.015 * radius);
            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-7 * Math.PI / 18),
                           y + (radius - 0.15 * radius) * Math.sin (-7 * Math.PI / 18));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-7 * Math.PI / 18),
                 y + (radius - 0.07 * radius) * Math.sin (-7 * Math.PI / 18));
            cr.stroke ();
            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-8 * Math.PI / 18),
                           y + (radius - 0.15 * radius) * Math.sin (-8 * Math.PI / 18));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-8 * Math.PI / 18),
                           y + (radius - 0.07 * radius) * Math.sin (-8 * Math.PI / 18));
            cr.stroke ();
            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-10 * Math.PI / 18),
                 y + (radius - 0.15 * radius) * Math.sin (-10 * Math.PI / 18));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-10 * Math.PI / 18),
                           y + (radius - 0.07 * radius) * Math.sin (-10 * Math.PI / 18));
            cr.stroke ();
            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-11 * Math.PI / 18),
                           y + (radius - 0.15 * radius) * Math.sin (-11 * Math.PI / 18));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-11 * Math.PI / 18),
                 y + (radius - 0.07 * radius) * Math.sin (-11 * Math.PI / 18));
            cr.stroke ();
                // **** external arc arrow
            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-3 * Math.PI / 12),
                           y + (radius - 0.15 * radius) * Math.sin (-3 * Math.PI / 12));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-3 * Math.PI / 12 + Math.PI / 45),
                           y + (radius - 0.07 * radius) * Math.sin (-3 * Math.PI / 12 + Math.PI / 45));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-3 * Math.PI / 12 - Math.PI / 45),
                           y + (radius - 0.07 * radius) * Math.sin (-3 * Math.PI / 12 - Math.PI / 45));
            cr.line_to (x + (radius - 0.15 * radius) * Math.cos (-3 * Math.PI / 12),
                           y + (radius - 0.15 * radius) * Math.sin (-3 * Math.PI / 12));
            cr.fill ();
            cr.stroke ();

            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-9 * Math.PI / 12),
                           y + (radius - 0.15 * radius) * Math.sin (-9 * Math.PI / 12));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-9 * Math.PI / 12 + Math.PI / 45),
                           y + (radius - 0.07 * radius) * Math.sin (-9 * Math.PI / 12 + Math.PI / 45));
            cr.line_to (x + (radius - 0.07 * radius) * Math.cos (-9 * Math.PI / 12 - Math.PI / 45),
                           y + (radius - 0.07 * radius) * Math.sin (-9 * Math.PI / 12 - Math.PI / 45));
            cr.line_to (x + (radius - 0.15 * radius) * Math.cos (-9 * Math.PI / 12),
                           y + (radius - 0.15 * radius) * Math.sin (-9 * Math.PI / 12));
            cr.fill ();
            cr.stroke ();

            cr.move_to (x + (radius - 0.15 * radius) * Math.cos (-Math.PI / 2),
                           y + (radius - 0.15 * radius) * Math.sin (-Math.PI / 2));
            cr.line_to (x + radius * Math.cos (-Math.PI / 2 + Math.PI / 30), y + radius * Math.sin (-Math.PI / 2 + Math.PI / 30));
            cr.line_to (x + radius * Math.cos (-Math.PI / 2 - Math.PI / 30), y + radius * Math.sin (-Math.PI / 2 - Math.PI / 30));
            cr.line_to (x + (radius - 0.15 * radius) * Math.cos (-Math.PI / 2),
                           y + (radius - 0.15 * radius) * Math.sin (-Math.PI / 2));
            cr.fill ();
            cr.stroke ();
            cr.restore ();
        }

        private void draw_upper_base(Cairo.Context cr)
        {
              double x, y, radius;
              Cairo.Pattern pat;

              radius = _radius;
              x = _x;
              y = _y;

  // **** alpha arc
              cr.arc (x, y, radius - 0.15 * radius, 0, 2 * Math.PI);

              pat = new Cairo.Pattern.radial  (x, y, radius - 0.23 * radius, x, y, radius - 0.15 * radius);

              pat.add_color_stop_rgba (0, 0.3, 0.3, 0.3, 0.1);
              cr.set_source (pat);
              cr.fill ();
              cr.stroke ();

  // **** base arrow
              cr.new_sub_path ();
              cr.set_line_width (0.02 * radius);
              cr.set_source_rgba (0.3, 0.3, 0.3, 0.15);
              cr.move_to (x + (radius - 0.205 * radius) * Math.cos (-Math.PI / 2),
                             y + (radius - 0.205 * radius) * Math.sin (-Math.PI / 2));
              cr.line_to (x + (radius - 0.325 * radius) * Math.cos (-Math.PI / 2 + Math.PI / 30),
                             y + (radius - 0.325 * radius) * Math.sin (-Math.PI / 2 + Math.PI / 30));
              cr.line_to (x + (radius - 0.325 * radius) * Math.cos (-Math.PI / 2 - Math.PI / 30),
                             y + (radius - 0.325 * radius) * Math.sin (-Math.PI / 2 - Math.PI / 30));
              cr.line_to (x + (radius - 0.205 * radius) * Math.cos (-Math.PI / 2),
                             y + (radius - 0.205 * radius) * Math.sin (-Math.PI / 2));
              cr.close_path ();
              cr.stroke ();

              cr.new_sub_path ();
              cr.set_line_width (0.02 * radius);
              cr.set_source_rgb (1, 0.65, 0);
              cr.move_to (x + (radius - 0.18 * radius) * Math.cos (-Math.PI / 2),
                             y + (radius - 0.18 * radius) * Math.sin (-Math.PI / 2));
              cr.line_to (x + (radius - 0.3 * radius) * Math.cos (-Math.PI / 2 + Math.PI / 30),
                             y + (radius - 0.3 * radius) * Math.sin (-Math.PI / 2 + Math.PI / 30));
              cr.line_to (x + (radius - 0.3 * radius) * Math.cos (-Math.PI / 2 - Math.PI / 30),
                             y + (radius - 0.3 * radius) * Math.sin (-Math.PI / 2 - Math.PI / 30));
              cr.line_to (x + (radius - 0.18 * radius) * Math.cos (-Math.PI / 2),
                             y + (radius - 0.18 * radius) * Math.sin (-Math.PI / 2));
              cr.close_path ();
              cr.stroke ();

      // **** base quart arc
              cr.arc (x, y, radius + 0.009 * radius, Math.PI / 5, 4 * Math.PI / 5);
              cr.set_source_rgb (0.05, 0.05, 0.05);
              cr.fill ();
              cr.stroke ();
              cr.new_sub_path ();
              cr.set_line_width (0.02 * radius);
              cr.set_source_rgb (0.05, 0.05, 0.05);
              cr.move_to (x - 0.3 * radius, y + 0.60 * radius);
              cr.line_to (x - 0.2 * radius, y + 0.35 * radius);
              cr.line_to (x - 0.05 * radius, y + 0.35 * radius);
              cr.line_to (x - 0.05 * radius, y + 0.25 * radius);
              cr.line_to (x - 0.015 * radius, y + 0.15 * radius);
              cr.line_to (x - 0.015 * radius, y);
              cr.line_to (x + 0.015 * radius, y);
              cr.line_to (x + 0.015 * radius, y + 0.15 * radius);
              cr.line_to (x + 0.05 * radius, y + 0.25 * radius);
              cr.line_to (x + 0.05 * radius, y + 0.35 * radius);
              cr.line_to (x + 0.2 * radius, y + 0.35 * radius);
              cr.line_to (x + 0.3 * radius, y + 0.60 * radius);
              cr.fill ();
              cr.close_path ();
              cr.stroke ();

              cr.set_source_rgb (0, 0, 0);
              cr.set_line_width (0.06 * radius);
              cr.move_to (x - 0.61 * radius, y);
              cr.line_to (x - 0.2 * radius, y);
              cr.line_to (x - 0.1 * radius, y + 0.1 * radius);
              cr.line_to (x, y);
              cr.line_to (x + 0.1 * radius, y + 0.1 * radius);
              cr.line_to (x + 0.2 * radius, y);
              cr.line_to (x + 0.61 * radius, y);
              cr.stroke ();
              cr.set_source_rgb (1, 0.65, 0);
              cr.set_line_width (0.04 * radius);
              cr.move_to (x - 0.6 * radius, y);
              cr.line_to (x - 0.2 * radius, y);
              cr.line_to (x - 0.1 * radius, y + 0.1 * radius);
              cr.line_to (x, y);
              cr.line_to (x + 0.1 * radius, y + 0.1 * radius);
              cr.line_to (x + 0.2 * radius, y);
              cr.line_to (x + 0.6 * radius, y);
              cr.stroke ();
        }

        private void draw_dynamic (Cairo.Context cr)
        {
            double x, y, radius;
            radius = _radius;
            x = _x;
            y = _y;

            cr.save();
            cr.set_line_width (0.01 * radius);
            cr.arc (x, y, radius, 0, 2 * Math.PI);
            cr.set_source_rgb (0.05, 0.05, 0.05);

            cr.fill_preserve();
            cr.clip();
            cr.stroke ();

            _x = radius;
            _x = x;
            _y = y;
            draw_internal_sphere (cr);
            cr.restore();
            draw_external_arc(cr);
            draw_upper_base(cr);
        }

        public void update(double roll, double pitch)
        {
            if(roll > 360)
                roll = 360;
            if(roll < 0)
                roll = 0;

            if(pitch > 70)
                pitch = 70;
            if(pitch < -70)
                pitch = -70;
            _angle = roll;
            _trans_y = pitch;
//            init = false;
            redraw_canvas();
//            init = true;
        }

        private void redraw_canvas () {
            var window = get_window ();
            if (null == window) {
                return;
            }

            var region = window.get_clip_region ();
            // redraw the cairo canvas completely by exposing it
            window.invalidate_region (region, true);
            window.process_updates (true);
        }
    }
}
