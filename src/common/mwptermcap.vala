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

public class  MwpTermCap : Object {
    public static string ceol;
    public static string civis;
    public static string cnorm;
#if USE_TERMCAP
    private static char tbuf[1024];
#endif

    public static void init() {
        cnorm = civis = "";
        ceol="   ";
#if USE_TERMCAP
        if(1 == Tc.tgetent(tbuf, Environment.get_variable("TERM").data)) {
            char buf[64];
            char *pbuf = buf;
            unowned string s;
            if((s = Tc.tgetstr("ce", &pbuf)) != null)
                ceol = s.dup();
            if((s = Tc.tgetstr("vi", &pbuf)) != null)
                civis = s.dup();
            if((s = Tc.tgetstr("ve", &pbuf)) != null)
                cnorm = s.dup();
        }
#endif
    }
}
