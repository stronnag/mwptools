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

public struct HomePos
{
    double hlat;
    double hlon;
    bool valid;
}

public class MissionReplayThread : GLib.Object
{
    private const int MAXSLEEP = 20*1000; // 10 time speedup
    private const double MSPEED = 10.0;
    private const double MHERTZ = 5.0; // nominal reporting rate
    private const double NM2METRES = 1852.0;
    public signal void mission_replay_event(double lat, double lon, double cse);
    public signal void mission_replay_done();

    private bool is_mr = false;
    private bool running = false;
    private bool warmup;
    private double speed = MSPEED;
    private double dist = 0.0;

    private bool multijump = false;
    private struct JumpCounter
    {
        int idx;
        int count;
    }

    public void stop()
    {
        running = false;
    }

    public void set_mr(bool value)
    {
        is_mr = value;
    }

    private void outloc (double lat, double lon, double cse)
    {
        mission_replay_event(lat, lon,cse);
        Thread.usleep(MAXSLEEP);
    }

    private double fly_leg (double slat, double slon,
                            double elat, double elon)
    {
        double c,d;
        Geo.csedist(slat,slon,elat,elon,out d, out c);
        d *= NM2METRES;
        dist += d;

        if (!warmup)
        {
            int steps = (int)(Math.round(MHERTZ * d / speed));
            var delta = speed / 5.0 / NM2METRES;

            for(var i = 0; running && i < steps; i++)
            {
                Geo.posit(slat, slon, c, delta, out slat, out slon);
                outloc (slat, slon, c);
            }
        }
        return c;
    }

/*
  Given a location cy,cx
  calculate a PH with radius and time
  assuming we continue on course for radius, then circle
  return final position
*/

    private void iterate_ph (double cy, double cx, double brg,
                             int phtim, out double ry, out double rx)
    {
        var radius = 35.0;
        ry = cy;
        rx = cx;
        if (phtim > 0)
        {
            if(!warmup)
            {
                var simwait = phtim / speed;
                Timer timer = new Timer ();
                if(is_mr)
                {
                    while (running && timer.elapsed (null) < simwait)
                    {
                        Thread.usleep(MAXSLEEP);
                    }
                }
                else
                {
                    var rnm = radius / NM2METRES;
                    Geo.posit(cy, cx, brg, rnm, out ry, out rx);
                    fly_leg(cy,cx, ry, rx);
                    var lx = rx;
                    var ly = ry;
                    var deginc  = radius / 10;
                    while (running && timer.elapsed (null) < simwait)
                    {
                        double c,d;
                        brg += deginc;
                        brg = brg % 360.0;
                        Geo.posit(cy, cx, brg, rnm, out ry, out rx);
                        Geo.csedist(ly,lx,ry,rx, out d, out c);
                        lx = rx;
                        ly = ry;
                        outloc (ry, rx, c);
                    }
                }
                timer.stop ();
            }
            else
            {
                dist += (phtim * speed);
            }
        }
    }

    private void iterate_mission (MissionItem [] mi, HomePos h)
    {
	var ret = false;
        var n = 0;
        var lastn = 0;
        var nsize = mi.length;
        var lx = 0.0;
        var ly = 0.0;
        var valid = false;
        var cse = 0.0;
        var cx = 0.0;
        var cy = 0.0;
#if PREVTEST
    int jn = -1;
#endif

        JumpCounter [] jump_counts = {};

        if(multijump)
        {
            for (var i = 0; i < mi.length; i++)
            {
                if(mi[i].action == MSP.Action.JUMP)
                {
                    JumpCounter jc = {i, mi[i].param2};
                    jump_counts += jc;
                }
            }
        }


        for (;;)
        {
            if (n == nsize)
                break;

            var typ = mi[n].action;

            if (typ == MSP.Action.SET_POI || typ == MSP.Action.SET_HEAD)
            {
                n += 1;
                continue;
            }

            if (valid)
            {
                if (typ == MSP.Action.JUMP)
                {
#if PREVTEST
                    jn = n + 1;
#endif
                    if (mi[n].param2 == -1)
                        n = (int)mi[n].param1 - 1;
                    else
                    {
                        if (mi[n].param2 == 0)
                        {
                            if(multijump)
                            {
                                foreach(var jc in jump_counts)
                                {
                                    if(n == jc.idx)
                                    {
                                        mi[n].param2 = jc.count;
                                        break;
                                    }
                                }
                            }
                            n += 1;
                        }
                        else
                        {
                            mi[n].param2 -= 1;
                            n = (int)mi[n].param1 - 1;
                        }
                    }
                    continue;
                }

                if (typ == MSP.Action.RTH)
                {
                    ret = true;
                    break;
                }

                cy = mi[n].lat;
                cx = mi[n].lon;
                double d;
                Geo.csedist(ly,lx,cy,cx, out d, out cse);
#if PREVTEST
                if(warmup)
                {
                    print("WP #%d", lastn+1);
                    if (n < lastn) // JUMP
                    {
                        print(" - JUMP#%d", jn);
                    }
                    print(" - #%d %1.f\n", n+1,d*NM2METRES);
                }
#endif
                var nc = fly_leg(ly,lx,cy,cx);
                if (nc != -1)
                    cse = nc;

                    // handle PH
                if  (typ == MSP.Action.POSHOLD_TIME ||
                     typ == MSP.Action.POSHOLD_UNLIM)
                {
                    var phtim = (int)mi[n].param1;
                        // really we need cse from start ... in case wp1 is PH
                    if  (typ == MSP.Action.POSHOLD_UNLIM)
                        phtim = -1;
#if PREVTEST
                    if(warmup)
                        print("WP #%d - PH (%.1f)\n", n+1, phtim*speed);
#endif
                    if (phtim == -1 || phtim > 5)
                        iterate_ph(cy, cx, cse, phtim, out cy, out cx);
                }
                lastn = n;
                n += 1;
            }
            else
            {
                cy = mi[n].lat;
                cx = mi[n].lon;
                valid = true;
                n += 1;
            }
            lx = cx;
            ly = cy;
            if(!running)
                break;
        }

	if (running && ret && h.valid)
        {
#if PREVTEST
            if(warmup)
            {
                double d;
                Geo.csedist(cy,cx,h.hlat,h.hlon, out d, out cse);
                print("WP #%d to home %1.f\n", lastn+1, d*NM2METRES);
            }
#endif
            fly_leg(cy,cx,h.hlat,h.hlon);
            cy = h.hlat;
            cx = h.hlon;
        }
    }

    public Thread<int> run_mission (Mission m, HomePos h)
    {
        running = true;

        multijump = (Environment.get_variable("INAV_MULTIJUMP") != null);

        var thr = new Thread<int> ("preview", () => {
                bool [] passes = {true, false};

                foreach (var p in passes)
                {
                    warmup = p;
                    var mi = m.get_ways();
                    dist = 0.0;
                    if(h.valid)
                    {
                        fly_leg(h.hlat, h.hlon, mi[0].lat, mi[0].lon);
                    }
                    if(running && mi.length > 1)
                        iterate_mission(mi, h);
                    if(p)
                    {
                        speed = (dist/3000) * MSPEED;
#if PREVTEST
                        print("Distance %.2fm at %.2fm/s\n", dist, speed);
#endif
                    }
                }
                mission_replay_done();
                return 0;
            });
        return thr;
    }
#if PREVTEST
    public static int main (string[] args)
    {
        Mission ms;
        HomePos h = { 50.8047104, -1.4942621, true };
        if ((ms = XmlIO.read_xml_file (args[1])) != null)
        {
            var ml = new MainLoop();
            var mt = new MissionReplayThread();
            if(args.length > 2)
                mt.set_mr(true);

            mt.mission_replay_event.connect((la,lo,co) => {
                    stderr.printf("pos %f %f %.1f\n", la, lo, co);
                });

            mt.mission_replay_done.connect(() => {
                    ml.quit();
                });

            Thread<int> thr = null;

            Idle.add(() => {
                    thr = mt.run_mission(ms, h);
                    return false;
                });
            ml.run();
            thr.join();
        }
        return 0;
    }
#endif
}
