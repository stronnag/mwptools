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

public struct HomePos {
    double hlat;
    double hlon;
    bool valid;
}

private enum NAVMODE {
    NONE=0,
    POI,
    FIXED
}

private struct HeadingMode {
    uint8  mode;
    uint32 heading; // fixed heading
    double poi_lat;
    double poi_lon;
}

public class  MissionPreviewer : GLib.Object {
    public struct LegPreview {
        int p1;
        int p2;
        double cse;
        double legd;
        double dist;
    }

    private const int MAXSLEEP = 20*1000; // 10 time speedup
    private const double MSPEED = 10.0;
    private const double MHERTZ = 5.0; // nominal reporting rate
    private const double NM2METRES = 1852.0;
    public signal void mission_replay_event(double lat, double lon, double cse);
    public signal void mission_replay_done();

    private bool running = false;
    public bool warmup = false;
    public  double speed = MSPEED;
    public  double dist = 0.0;
    private MissionItem[] mi;
    private HeadingMode head_mode;

    public bool is_mr = false;
    public bool indet { get; private set; default = false; }

    private int[] jumpC;

    public MissionPreviewer() {
        warmup = true;
        running = true;
        head_mode = {0};
    }

    public void stop() {
        running = false;
    }

    private void outloc (double lat, double lon, double cse) {
        switch (head_mode.mode) {
            case NAVMODE.NONE:
                break;
            case NAVMODE.POI:
                double d;
                Geo.csedist(lat,lon, head_mode.poi_lat,head_mode.poi_lon, out d, out cse);
                break;
            case NAVMODE.FIXED:
                cse = head_mode.heading;
                break;
        }
        mission_replay_event(lat, lon,cse);
        Thread.usleep(MAXSLEEP);
    }

    private void fly_leg (double slat, double slon, double elat, double elon,
                          out double c, out double d) {
        Geo.csedist(slat,slon,elat,elon,out d, out c);
        d *= NM2METRES;
        dist += d;

        if (!warmup) {
            int steps = (int)(Math.round(MHERTZ * d / speed));
            var delta = speed / 5.0 / NM2METRES;

            for(var i = 0; running && i < steps; i++) {
                Geo.posit(slat, slon, c, delta, out slat, out slon);
                outloc (slat, slon, c);
            }
        }
    }

/*
  Given a location cy,cx
  calculate a PH with radius and time
  assuming we continue on course for radius, then circle
  return final position
*/

    private void iterate_ph (double cy, double cx, double brg,
                             int phtim, out double ry, out double rx) {
        const double RADIUS = 35.0;
        ry = cy;
        rx = cx;
        if (phtim > 0) {
            if(!warmup) {
                var simwait = phtim / speed;
                Timer timer = new Timer ();
                if(is_mr) {
                    while (running && timer.elapsed (null) < simwait) {
                        Thread.usleep(MAXSLEEP);
                    }
                } else {
                    const double DEGINC = 5;
                    const double SECS_CIRC = 2*Math.PI*RADIUS/MSPEED;
                    const double RNM = RADIUS / NM2METRES;
                    double c,d;
                    Geo.posit(cy, cx, brg, RNM, out ry, out rx);
                    fly_leg(cy,cx, ry, rx, out c, out d);
                    var lx = rx;
                    var ly = ry;
                    var bcnt = 0;
                    var maxbcnt = (int) (phtim*360/SECS_CIRC/DEGINC);
                    while (running && bcnt < maxbcnt) {
                        brg += DEGINC;
                        brg = brg % 360.0;
                        Geo.posit(cy, cx, brg, RNM, out ry, out rx);
                        Geo.csedist(ly,lx,ry,rx, out d, out c);
                        lx = rx;
                        ly = ry;
                        outloc (ry, rx, c);
                        bcnt++;
                    }
                }
                timer.stop ();
            } else {
                if(!is_mr)
                    dist += (phtim * speed);
            }
        }
    }

    private void setupJumpCounters() {
        for (var i = 0; i < mi.length; i++)
            if(mi[i].action == MSP.Action.JUMP)
                jumpC[i] = mi[i].param2;
    }

    private void clearJumpCounters() {
        for (var i = 0; i < mi.length; i++)
            if(mi[i].action == MSP.Action.JUMP)
                jumpC[i] = 0;
    }

    private void resetJumpCounter(int n) {
        jumpC[n] = mi[n].param2;
    }

    public LegPreview[] iterate_mission (HomePos h) {
		var ret = false;
        var n = 0;
        var lastn = 0;
        var lx = 0.0;
        var ly = 0.0;
        var valid = false;
        var cse = 0.0;
        var cx = 0.0;
        var cy = 0.0;
        double d;
        LegPreview[] plist={};
        head_mode = {0};
#if TREED
		Tree<int, LegPreview?> tree = new Tree<int, LegPreview?>((a,b) => {return (a-b);});
#endif
		var nsize = mi.length;

        jumpC = new int[nsize];

        if(warmup) {
            dist = 0.0;
        } else {
            if (dist < 3000) {
                speed = MSPEED/4 + (MSPEED*3/4) * (dist/3000);
            } else
                speed = (dist/3000) * MSPEED;
        }

        setupJumpCounters();

        if(h.valid) {
            fly_leg(h.hlat, h.hlon, mi[0].lat, mi[0].lon, out cse, out d);
            if(warmup) {
                LegPreview p = {-1, n, cse, dist, dist};
                plist += p;
            }
        }

        for (;;) {
            if(!running)
                break;

            if (n >= nsize)
                break;

            var typ = mi[n].action;

            if (valid) {
                if (typ == MSP.Action.SET_POI) {
                    head_mode.mode = NAVMODE.POI;
                    head_mode.poi_lat = mi[n].lat;
                    head_mode.poi_lon = mi[n].lon;
                    n += 1;
                    continue;
                }

                if (typ == MSP.Action.SET_HEAD) {
                    var fhead = (int)mi[n].param1;
                    if (fhead < 0 || fhead > 359) {
                        head_mode.mode = NAVMODE.NONE;
                    } else {
                        head_mode.mode = NAVMODE.FIXED;
                        head_mode.heading = fhead;
                    }
                    n += 1;
                    continue;
                }

                if (typ == MSP.Action.JUMP) {
                    if (jumpC[n] == -1) {
                        indet = true;
                        if (warmup) {
                            n += 1;
                        } else {
                            n = (int)mi[n].param1 - 1;
						}
                    } else {
                        if (jumpC[n] == 0) {
                            resetJumpCounter(n);
                            n += 1;
                        } else {
                            jumpC[n] -= 1;
                            n = (int)mi[n].param1 - 1;
                        }
                    }
                    continue;
                }

                if (typ == MSP.Action.RTH) {
                    ret = true;
                    break;
                }

				cy = mi[n].lat;
				cx = mi[n].lon;
				double nc;
#if TREED
				unowned LegPreview? px;
				int ky = (int)((lastn<<16)|(n&0xffff));
				px = tree.lookup(ky);
				if(px == null) {
					fly_leg(ly,lx,cy,cx, out nc, out d);
					LegPreview np;
                    np = {lastn, n, nc, d, dist};
					tree.insert(ky, np);
				} else {
					nc = px.cse;
					d = px.legd;
					dist += d;
				}
#else
				fly_leg(ly,lx,cy,cx, out nc, out d);
#endif
                if(warmup) {
					LegPreview p = {lastn, n, nc, d, dist};
                    plist += p;
                }

                if (nc != -1)
                    cse = nc;

                    // handle PH
                if  (typ == MSP.Action.POSHOLD_TIME || typ == MSP.Action.POSHOLD_UNLIM) {
                    var phtim = (int)mi[n].param1;
                        // really we need cse from start ... in case wp1 is PH
                    if  (typ == MSP.Action.POSHOLD_UNLIM)
                        phtim = -1;

                    if (phtim == -1 || phtim > 5)
                        iterate_ph(cy, cx, cse, phtim, out cy, out cx);
                }
                lastn = n;
                n += 1;
            } else {
                cy = mi[n].lat;
                cx = mi[n].lon;
                valid = true;
                n += 1;
            }
            lx = cx;
            ly = cy;
		}

		if (running && ret && h.valid) {
            fly_leg(ly, lx, h.hlat, h.hlon, out cse, out d);
            cy = h.hlat;
            cx = h.hlon;
            if(warmup) {
                LegPreview p = {lastn, -1, cse, d, dist};
                plist += p;
            }
        }
        clearJumpCounters();
		return plist;
    }

    public  LegPreview[]  check_mission (Mission ms, HomePos h) {
        mi = ms.get_ways();
        return iterate_mission(h);
    }

    public Thread<int> run_mission (Mission ms, HomePos h) {
        mi = ms.get_ways();
        iterate_mission(h);
        var thr = new Thread<int> ("preview", () => {
                warmup = false;
                if(running)
                    iterate_mission(h);
                mission_replay_done();
                return 0;
            });
        return thr;
    }

#if PREVTEST
    public string fmtwp(int n) {
        string s;
        var typ = mi[n].action;

        if(n == -1)
            s = "Home";
        else {
            n += 1;
            if(typ == MSP.Action.JUMP)
                s = "(J%02d)".printf(n);
            else if (typ == MSP.Action.POSHOLD_TIME)
                s = "PH%02d".printf(n);
            else
                s = "WP%02d".printf(n);

        }
        return s;
    }

    private static bool nohome = false;
    private static bool mr = false;
    private static bool checker = false;
    private static bool minchecker = false;
    private static string hp = null;

    const OptionEntry[] options = {
        { "nohome", '0', 0, OptionArg.NONE, out nohome, "No home", null},
        { "home", '0', 0, OptionArg.STRING, out hp, "lat,lon", null},
        { "multi-rotor", 'm', 0, OptionArg.NONE, out mr, "mr mode", null},
        { "check", 'c', 0, OptionArg.NONE, out checker, "check only", null},
        { "mincheck", 'C', 0, OptionArg.NONE, out minchecker, "check only", null},
        {null}
    };

    private void show_leg(LegPreview p) {
        StringBuilder sb = new StringBuilder();
        sb.append(fmtwp(p.p1));
        if(p.p1 != -1 && p.p2 != -1 && p.p1 > p.p2) { // JUMPING
            sb.append(" ");
            sb.append(fmtwp(p.p1+1));
            sb.append(" ");
        } else
            sb.append(" - ");
        sb.append(fmtwp(p.p2));
        sb.append_printf("\t%03.0f°\t%4.0fm\t%5.0fm\n", p.cse, p.legd, p.dist);
        stdout.puts(sb.str);
    }

    public static bool mission_is_json(string fn) {
        uint8 buf[16];
        var fs = FileStream.open (fn, "r");
        fs.read (buf);
        if (((string)buf).contains("<?xml"))
            return false;
        else
            return true;
    }

    public static int main (string[] args) {
        try {
            var opt = new OptionContext(" - test args");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        } catch (OptionError e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available "+
                          "options\n", args[0]);
            return 1;
        }

#if TREED
		stderr.printf("Using Binary Tree cache\n");
#endif
		if (minchecker)
			checker = true;

		Mission ms;
        var fn = args[1];
        var is_j = MissionPreviewer.mission_is_json(fn);
        var msx =  (is_j) ? JsonIO.read_json_file(fn) : XmlIO.read_xml_file (fn);
		ms = msx[0];
        if (ms != null) {
            HomePos h = {0};
			if (ms.homex != 0 && ms.homey != 0) {
				h = { ms.homey, ms.homex, true };
			} else if(hp != null) {
                var parts = hp.split(",");
                if (parts.length == 2) {
                    h.hlat = double.parse(parts[0]);
                    h.hlon = double.parse(parts[1]);
                    h.valid = true;
                }
            } else {
                h = { 50.8047104, -1.4942621, true };
            }

            h.valid = !nohome;

            var mt = new MissionPreviewer();

            mt.is_mr = mr;

            if(checker) {
				double secs;
				var t = new Timer();
                var plist =  mt.check_mission(ms, h);
				t.stop ();
				secs = t.elapsed (null);
				stderr.printf("Time %.6f\n", secs);
				if (minchecker) {
					stderr.printf("mincheck: %d %f\n", plist.length, plist[plist.length-1].dist);
				} else {
					stdout.puts("WP / next wp\tCourse\t Dist\t Total\n");
					foreach(var p in plist)	{
						mt.show_leg(p);
					}
				}
            } else {
                Thread<int> thr = null;
                var ml = new MainLoop();

                mt.mission_replay_event.connect((la,lo,co) => {
                        stderr.printf("pos %f %f %.1f\n", la, lo, co);
                    });

                mt.mission_replay_done.connect(() => {
                        ml.quit();
                    });

                Idle.add(() => {
                        thr = mt.run_mission(ms, h);
                        return false;
                    });
                thr.join();
                ml.run(/* */);
            }
        }
        return 0;
    }
#endif
}
