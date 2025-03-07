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

namespace Units {
    private const string [] dnames = {"m", "ft", "yd","mfg"};
    private const string [] dspeeds = {"m/s", "kph", "mph", "kts", "mfg/µftn"};
    private const string [] dfix = {"no fix","","2d","3d"};

    public double distance (double d) {
        switch(Mwp.conf.p_distance) {
            case 1:
                d *= 3.2808399;
                break;
            case 2:
                d *= 1.0936133;
                break;
            case 3: // millifurlongs
                d *= 0.0049709695;
                break;
        }
        return d;
    }

    public double speed (double d) {
        switch(Mwp.conf.p_speed) {
            case 1:
                d *= 3.6;
                break;
            case 2:
                d *= 2.2369363;
                break;
            case 3:
                d *= 1.9438445;
                break;
            case 4: // milli-furlongs / micro-fortnight
                d *= (6012.8848/1000.0);
                break;
        }
        return d;
    }

	/*
      <summary>Units for GA Speed</summary>
      <description>0=m/s, 1=kph, 2=mph, 3=knots</description>
	*/

	public string ga_speed(double d) {
		string du = "m/s";

        switch(Mwp.conf.ga_speed) {
		case 0:
			break;
		case 2:
			d *= 2.2369363;
			du = "mph";
			break;
		case 3:
			d *= 1.9438445;
			du = "kt";
			break;
		default :
			du = "kph";
			d *= 3.6;
			break;

        }
		return "%.0f %s".printf(d, du);
	}

	/*
      <summary>Units for GA Range</summary>
      <description>0=m, 1=km, 2=miles, 3=nautical miles</description>
	*/

	public string ga_range(double d) {
		string du = "m";
		string fmt = "%.0f %s";

        switch(Mwp.conf.ga_range) {
		case 0:
			break;
		case 2:
			d /= 1609.344;
			du = "mi";
			break;
		case 3:
			d /= 1852.0;
			du = "nm";
			break;
		default:
			d /= 1000.0;
			du = "km";
			break;
		}

		if (d < 1.0) {
			fmt = "%.3f %s";
		} else if (d < 10.0) {
			fmt = "%.1f %s";
		}
		return fmt.printf(d,du);
	}

	/*
      <summary>Units for GA Altiude</summary>
      <description>0=m, 1=ft, 2=FL</description>
	*/

	public string ga_alt(double d) {
		string du = "m";
		string fmt = "%.0f %s";

        switch(Mwp.conf.ga_alt) {
		case 1:
			d *= 3.2808399;
			du = "ft";
			break;
		case 2:
			d *= 0.032808399;
			du = "";
			fmt="FL%.0f%s";
			break;
		default:
			du = "m";
			break;
		}
		return fmt.printf(d,du);
	}

	public double va_speed (double d) {
        if (Mwp.conf.p_speed > 1)
			d *= 3.2808399; // ft/sec
        return d;
    }

    public string distance_units() {
        return dnames[Mwp.conf.p_distance];
    }

    public string speed_units() {
        return dspeeds[Mwp.conf.p_speed];
    }

    public string va_speed_units() {
        return (Mwp.conf.p_speed > 1) ? "ft/s" : "m/s";
    }

    public string fix(uint8 fix) {
            // Just for an external replayer and the fact that inav does
            // this differently from mw
        if (fix >= dfix.length)
            fix--;
        return dfix[fix];
    }

	public void scaled_distance(double d, out string sd, out string su, bool isalt=false) {
		sd = "0";
		su = "?";
		switch (Mwp.conf.p_distance) {
		case 0: // m
			if (d.abs() < 10000.0) {
				sd = "%.0f".printf(d);
				su = dnames[Mwp.conf.p_distance];
			} else {
				d /= 1000;
				if (d.abs() < 100.0) {
					sd = "%.1f".printf(d);
				} else {
					sd = "%.0f".printf(d);
				}
				su = "km";
			}
			break;
		case 1:
		case 2:
			var du = Units.distance(d);
			if (!isalt) {
				if (d.abs() < 1609.344) {
					sd = "%.0f".printf(du);
					su = dnames[Mwp.conf.p_distance];
				} else {
					du = d / 1609.344;
					if (du.abs() < 100.0) {
						sd = "%.1f".printf(du);
					} else {
						sd = "%.0f".printf(du);
					}
					su = "mi";
				}
			} else {
				d *= 3.2808399;
				if (d.abs() < 10000.0) {
					sd = "%.0f".printf(d);
					su = "ft";
				} else {
					d /= 1000;
					if (d.abs() < 100.0) {
						sd = "%.1f".printf(d);
					} else {
						sd = "%.0f".printf(d);
					}
					su="kft";
				}
			}
			break;
		default:
			break;
		}
	}
}
