// Handle Secondary Devices

public class TelemTracker {
    private const double RAD2DEG = 57.29578;

    public signal void changed();

    public enum Status {
        UNDEF = 0,
        PRESENT = 1,
        USED  = 2,
    }

	public struct SecDev {
		MWSerial dev;
		string name;
        string alias;
        Status status;
        MWSerial.PMask pmask;
	}

    internal SecDev[] secdevs;
    private MWP mp;

    public TelemTracker(MWP _mp) {
        mp = _mp;
        secdevs = {};
        string s2;
        if((s2 = Environment.get_variable("MWP_SECDEVS")) != null) {
            var parts = s2.split("|");
            foreach(var p in parts) {
                add(p);
            }
        }
    }

    public void show_dialog() {
        Status []xstat={};
        foreach (var s in secdevs) {
            xstat += s.status;
        }
        var s = new SecDevDialog(this);
        s.destroy.connect(() => {
                for(int n = 0; n < secdevs.length; n++) {
                    if(secdevs[n].status != xstat[n]) {
                        switch (secdevs[n].status) {
                        case Status.USED:
                        start_reader(n);
                        break;
                        case Status.PRESENT:
                        case Status.UNDEF:
                        if (xstat[n] ==  Status.USED) {
                            stop_reader(n);
                        }
                        break;
                        }
//                        stderr.printf("DBG: %d: %d -> %d\n", n, xstat[n], secdevs[n].status);
                    }
                }
            });
        s.run();
    }

    public bool is_used(string sname) {
        var parts = sname.split(" ", 2);
        foreach (var s in secdevs) {
            if (s.name == parts[0] && s.status == Status.USED) {
                return true;
            }
        }
        return false;
    }


    public void add(string sname) {
        bool found = false;
        string devname;
        MWSerial.PMask pmask;

        var parts = sname.split(" ", 2);
        var subparts = parts[0].split("#");
        if (subparts.length == 2) {
            devname = subparts[0];
            pmask = MWSerial.name_to_pmask(subparts[1]);
        } else {
            devname = parts[0];
            pmask = MWSerial.PMask.AUTO;
        }

        for(int n = 0; n < secdevs.length; n++) {
            if (secdevs[n].name == devname) {
                secdevs[n].status = Status.PRESENT;
                found = true;
                break;
            }
        }

        if(!found) {
            var s = SecDev();
            s.status = Status.PRESENT;
            s.name = devname;
            if (parts.length == 2) {
                s.alias = parts[1];
            } else {
                string suffix;
                if (sname.has_prefix("/dev/")) {
                    suffix = sname[5:sname.length];
                } else {
                    suffix = sname;
                }
                s.alias = "TTRK-%s".printf(suffix);
            }
            s.dev = null;
            s.pmask = pmask;
            secdevs += s;
        }
        changed();
    }

    public void remove(string sname) {
        disable(sname);
    }

    public void enable(string sname) {
        var parts = sname.split(" ", 2);
        for(int n = 0; n < secdevs.length; n++) {
            if (secdevs[n].name == parts[0]) {
                secdevs[n].status = Status.PRESENT;
                break;
            }
        }
        changed();
    }

    public void disable(string sname) {
        var parts = sname.split(" ", 2);
        for(int n = 0; n < secdevs.length; n++) {
            if (secdevs[n].name == parts[0]) {
                secdevs[n].status = Status.UNDEF;
                break;
            }
        }
        changed();
    }
    /**
    private void display(string act, string dev) {
        stderr.printf("DBG *** %s %s ***\n", act, dev);
        foreach (var s in secdevs) {
            stderr.printf("\tDBG n=<%s> a=<%s> s=%d\n", s.name, s.alias, s.status);
        }
    }
    **/
    private void start_reader(int n) {
        if (secdevs[n].dev == null) {
            secdevs[n].dev = new MWSerial();
        }
        secdevs[n].dev.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
                process_ltm_mav(s, cmd, raw, len,xflags,errs,n);
            });

        secdevs[n].dev.crsf_event.connect((raw) => {
                process_crsf(raw,n);
            });

        secdevs[n].dev.flysky_event.connect((raw) => {
                process_flysky(raw, n);
            });

        secdevs[n].dev.sport_event.connect((id,val) => {
                process_sport (id, val, n);
            });

        secdevs[n].dev.serial_lost.connect(() => {
                stop_reader(n);
                stderr.printf("DBG: Reader stopped, check dialog!!!!!\n");
            });

        string fstr = null;
        if(! secdevs[n].dev.available) {
            if(secdevs[n].dev.open (secdevs[n].name, 115200, out fstr) == true) {
                MWPLog.message("start secondary reader %s\n", secdevs[n].name);
                if(mp.rawlog)
                    secdevs[n].dev.raw_logging(true);
                secdevs[n].dev.set_pmask(secdevs[n].pmask);
                secdevs[n].dev.set_auto_mpm(secdevs[n].pmask == MWSerial.PMask.AUTO);
            } else {
                MWPLog.message("Radar reader %s\n", fstr);
            }
        }
    }

    private void stop_reader(int n) {
        if (secdevs[n].dev.available) {
            secdevs[n].dev.close();
        }
        secdevs[n].dev = null;
    }

    private void  process_ltm_mav(MWSerial s, MSP.Cmds cmd, uint8[] raw, uint len,
                                  uint8 xflags, bool errs, int n) {
        bool can_update = false;
        unowned RadarPlot? ri = get_ri(n);
        switch (cmd) {
        case MSP.Cmds.TG_FRAME:
            LTM_GFRAME gf = LTM_GFRAME();
            uint8* rp;
            rp = SEDE.deserialise_i32(raw, out gf.lat);
            rp = SEDE.deserialise_i32(rp, out gf.lon);
            gf.speed = *rp++;
            rp = SEDE.deserialise_i32(rp, out gf.alt);
            gf.sats = *rp;
            ri.latitude = gf.lat / 1e7;
            ri.longitude = gf.lon / 1e7;
            ri.speed = gf.speed;
            ri.altitude = gf.alt /100.0;
            ri.posvalid = (gf.sats > 5);
            can_update = true;
            break;
        case MSP.Cmds.TA_FRAME:
            uint16 h;
            SEDE.deserialise_i16(raw+4, out h);
             if(h < 0)
                 h += 360;
            ri.heading = h;
            break;
        case MSP.Cmds.TS_FRAME:
            if ((raw[6] & 1) == 1) {
                ri.state = RadarView.Status.ARMED;
            } else {
                ri.state = RadarView.Status.UNDEF;
            }
            break;

        case MSP.Cmds.MAVLINK_MSG_ID_HEARTBEAT:
            Mav.MAVLINK_HEARTBEAT m = *(Mav.MAVLINK_HEARTBEAT*)raw;
            if ((m.base_mode & 128) == 128) {
                ri.state = RadarView.Status.ARMED;
            } else {
                ri.state = RadarView.Status.UNDEF;
            }
            break;

        case MSP.Cmds.MAVLINK_MSG_GPS_RAW_INT:
            Mav.MAVLINK_GPS_RAW_INT m = *(Mav.MAVLINK_GPS_RAW_INT*)raw;
            ri.latitude = m.lat / 1e7;
            ri.longitude = m.lon / 1e7;
            if (m.vel != 0xffff) {
                ri.speed = m.vel/100;
            }
            ri.altitude = m.alt / 1000;
            if (m.vel != 0xffff) {
                ri.heading = m.cog/100;
            }
            ri.posvalid = (m.fix_type > 2 && m.satellites_visible != 0xff && m.satellites_visible  > 5);
            can_update = true;
            break;

        case MSP.Cmds.MAVLINK_MSG_ATTITUDE:
                Mav.MAVLINK_ATTITUDE m = *(Mav.MAVLINK_ATTITUDE*)raw;
				var mhead = (m.yaw*RAD2DEG);
				if(mhead < 0)
					mhead += 360;
                ri.heading = (uint16)mhead;
                break;

        default:
            break;
        }
        if(can_update && ri.posvalid) {
            ri.lasttick = mp.nticks;
            mp.markers.update_radar(ref ri);
            mp.radarv.update(ref ri, false);
        }
    }

    private void  process_crsf(uint8 []buffer, int n) {
         uint8 id = buffer[2];
         uint8 *ptr = &buffer[3];
         uint32 val32;
         uint16 val16;

         unowned RadarPlot? ri = get_ri(n);
         switch(id) {
             case CRSF.GPS_ID:
                 ptr= SEDE.deserialise_u32(ptr, out val32);  // Latitude (deg * 1e7)
                 int32 lat = (int32)Posix.ntohl(val32);
                 ri.latitude = lat / 1e7;
                 ptr= SEDE.deserialise_u32(ptr, out val32); // Longitude (deg * 1e7)
                 int32 lon = (int32)Posix.ntohl(val32);
                 ri.longitude = lon / 1e7;
                 ptr= SEDE.deserialise_u16(ptr, out val16); // Groundspeed ( km/h * 10 )
                 double gspeed = 0;
                 if (val16 != 0xffff) {
                     gspeed = Posix.ntohs(val16) / 36.0; // m/s
                     ri.speed = gspeed;
                 }
                 ptr= SEDE.deserialise_u16(ptr, out val16);  // COG Heading ( degree * 100 )
                 double hdg = 0;
                 if (val16 != 0xffff) {
                     hdg = Posix.ntohs(val16) / 100.0; // deg
                     ri.heading = (uint16)hdg;
                 }
                 ptr= SEDE.deserialise_u16(ptr, out val16);
                 int32 alt= (int32)Posix.ntohs(val16) - 1000; // m
                 ri.altitude = alt;
                 uint8 nsat = *ptr;
                 ri.posvalid = (nsat > 5);
                 ri.state = RadarView.Status.ARMED;
                 if (ri.posvalid) {
                     ri.lasttick = mp.nticks;
                     mp.markers.update_radar(ref ri);
                     mp.radarv.update(ref ri, false);
                 }
                 break;
         case CRSF.FM_ID: // armed check
             break;

         default:
             break;
         }
    }

    private  unowned RadarPlot? get_ri(int n) {
        unowned RadarPlot? ri = mp.find_radar_data((uint)n);
        if (ri == null) {
            var r0 = RadarPlot();
            r0.id =  (uint)n;
            mp.radar_plot.append(r0);
            ri = mp.find_radar_data((uint)n);
            ri.name = secdevs[n].alias;
            ri.source = RadarSource.TELEM;
            ri.posvalid = false;
        }
        return ri;
    }

    private void  process_flysky(uint8[] raw, int n) {
        FLYSKY.Telem t;
		if(FLYSKY.decode(raw, out t)) {
            unowned RadarPlot? ri = get_ri(n);
            if ((t.mask & (1 << FLYSKY.Func.LAT0|FLYSKY.Func.LAT1|FLYSKY.Func.LON0|FLYSKY.Func.LON1|FLYSKY.Func.STATUS)) != 0) {
                int nsat = (t.status / 1000);
                int ifix = (t.status % 1000) / 100;
                ri.posvalid = (((ifix & 2) == 2) && nsat > 5);
                ri.latitude = t.ilat / 1e7;
                ri.longitude = t.ilon / 1e7;
                if (ifix > 4) {
                    ri.state = RadarView.Status.ARMED;
                } else {
                    ri.state = RadarView.Status.UNDEF;
                }
            }
            if((t.mask & (1 << FLYSKY.Func.ALT)) !=0 ) {
                ri.altitude = t.alt;
            } else if((t.mask & (1 << FLYSKY.Func.GALT)) !=0 ) {
                ri.altitude = t.galt;
            }
            if((t.mask & (1 << FLYSKY.Func.HEADING)) !=0 ) {
                ri.heading = (uint16)t.heading;
            } else if((t.mask & (1 << FLYSKY.Func.COG)) !=0 ) {
                ri.heading = (uint16)t.cog;
            }
            if (ri.posvalid) {
                ri.lasttick = mp.nticks;
                mp.markers.update_radar(ref ri);
                mp.radarv.update(ref ri, false);
            }
        }
    }

    private uint8 sport_parse_lat_lon(uint val, out int32 value) {
        uint8 imode = (uint8)(val >> 31);
        value = (int)(val & 0x3fffffff);
        if ((val & (1 << 30))!= 0)
            value = -value;
        value = (50*value) / 3; // min/10000 => deg/10000000
        return imode;
    }

    private void  process_sport(uint32 id, uint32 val, int n) {
        unowned RadarPlot? ri = get_ri(n);
        switch(id) {
        case SportDev.FrID.GPS_LONG_LATI_ID:
            int32 ipos = 0;
            uint8 lorl = sport_parse_lat_lon (val, out ipos);
            if (lorl == 0) {
                ri.latitude = ipos / 1e7;
            } else {
                ri.longitude = ipos / 1e7;
            }
            break;

        case SportDev.FrID.GPS_ALT_ID:
            ri.altitude = ((int)val) / 100.0;
            break;

        case SportDev.FrID.GPS_SPEED_ID:
            ri.speed  = ((val/1000.0)*0.51444444);
            break;

        case SportDev.FrID.GPS_COURS_ID:
            ri.heading = (uint16)(val / 100);
            break;

        case SportDev.FrID.ALT_ID:
            ri.altitude = (int)val / 100.0;
            break;

        case SportDev.FrID.T1_ID: // flight modes
            uint ival = val;
            var modeU = ival % 10;
            if ((modeU & 4) == 4) { // armed
                ri.state = RadarView.Status.ARMED;
            } else {
                ri.state = RadarView.Status.UNDEF;
            }
            break;

        case SportDev.FrID.T2_ID: // GPS info
            var nsats = (uint8)(val % 100);
            var gfix = (uint8)(val /1000);
            if ((gfix & 2) == 2) {
                ri.posvalid =  (nsats > 5);
                if(ri.posvalid) {
                    ri.lasttick = mp.nticks;
                    mp.markers.update_radar(ref ri);
                    mp.radarv.update(ref ri, false);
                }
            }
            break;

        default:
            break;
        }
    }
}

public class  SecDevDialog : Gtk.Window {
    private Gtk.TreeView tview;
    private Gtk.ListStore sd_liststore;
    private Gtk.ListStore combo_model;

    private TelemTracker tt;
    enum Column {
        NAME,
        ALIAS,
        STATUS,
        PMASK,
        ID,
        NO_COLS
    }

    public SecDevDialog( TelemTracker _tt) {
        tt = _tt;
        this.title = "Telemetry Tracker";

        var sd_ok = new Gtk.Button.with_label("Close");
        sd_ok.clicked.connect(() => {
                this.destroy();
            });

        //        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
        var grid = new Gtk.Grid ();
        grid.set_vexpand (true);

        if(tt.secdevs.length > 0) {
            sd_liststore = new Gtk.ListStore (Column.NO_COLS,
                                              typeof (string),
                                              typeof (string),
                                              typeof (bool),
                                              typeof (string),
                                              typeof(int)
                                              );

            tview = new Gtk.TreeView.with_model (sd_liststore);
            tview.set_hexpand(true);
            tview.set_vexpand (true);
            tview.set_fixed_height_mode (true);
            //            tview.set_model (sd_liststore);
            tview.insert_column_with_attributes (-1, "Device",
                                                 new Gtk.CellRendererText (), "text",
                                                 Column.NAME);

            var cell = new Gtk.CellRendererText ();
            tview.insert_column_with_attributes (-1, "Alias", cell, "text", Column.ALIAS);
            cell.set_property ("editable", true);
            ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                    Gtk.TreeIter iter;
                    int idx=0;
                    sd_liststore.get_iter(out iter, new Gtk.TreePath.from_string(path));
                    sd_liststore.get (iter, Column.ID, &idx);
                    tt.secdevs[idx].alias = new_text;
                    sd_liststore.set (iter, Column.ALIAS,new_text);
                });

            var tcell = new Gtk.CellRendererToggle();
            tview.insert_column_with_attributes (-1, "Enable",
                                                 tcell, "active", Column.STATUS);
            tcell.toggled.connect((p) => {
                    Gtk.TreeIter iter;
                    int idx = 0;
                    sd_liststore.get_iter(out iter, new Gtk.TreePath.from_string(p));
                    sd_liststore.get (iter, Column.ID, &idx);
                    tt.secdevs[idx].status = (tt.secdevs[idx].status == TelemTracker.Status.USED) ? TelemTracker.Status.PRESENT : TelemTracker.Status.USED;
                    sd_liststore.set (iter, Column.STATUS, (tt.secdevs[idx].status == TelemTracker.Status.USED));
                });

            Gtk.TreeIter iter;
            combo_model = new Gtk.ListStore (2, typeof (string), typeof(MWSerial.PMask));
            combo_model.append (out iter);
            combo_model.set (iter, 0, "Auto", 1, MWSerial.PMask.AUTO);
            combo_model.append (out iter);
            combo_model.set (iter, 0, "INAV", 1, MWSerial.PMask.INAV);
            combo_model.append (out iter);
            combo_model.set (iter, 0, "SPort", 1, MWSerial.PMask.SPORT);
            combo_model.append (out iter);
            combo_model.set (iter, 0, "CRSF", 1, MWSerial.PMask.CRSF);
            combo_model.append (out iter);
            combo_model.set (iter, 0, "MPM", 1, MWSerial.PMask.MPM);

            Gtk.CellRendererCombo combo = new Gtk.CellRendererCombo ();
            combo.set_property ("editable", true);
            combo.set_property ("model", combo_model);
            combo.set_property ("text-column", 0);
            combo.set_property ("has-entry", false);
            tview.insert_column_with_attributes (-1, "Hint",
                                                 combo, "text", Column.PMASK);

            combo.changed.connect((path, iter_new) => {
                    Gtk.TreeIter iter_val;
                    Value val;
                    int idx=0;
                    MWSerial.PMask pmask;
                    combo_model.get_value (iter_new, 0, out val);
                    string hint = (string)val;
                    combo_model.get_value (iter_new, 1, out val);
                    pmask = (MWSerial.PMask)val;
                    sd_liststore.get_iter (out iter_val, new Gtk.TreePath.from_string (path));
                    sd_liststore.get (iter_val, Column.ID, &idx);
                    sd_liststore.set (iter_val, Column.PMASK, hint);
                    tt.secdevs[idx].pmask = pmask;
                });

            int [] widths = {30, 40, 8, 10};
            for (int j = Column.NAME; j < Column.ID; j++) {
                var scol =  tview.get_column(j);
                if(scol!=null) {
                    scol.set_min_width(7*widths[j]);
                    scol.resizable = true;
                    scol.set_sort_column_id(j);
                }
            }

            var n =populate_view();
            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            scrolled.min_content_height = (2+n)*30;
            //scrolled.min_content_width = 320;
            scrolled.add(tview);
            scrolled.propagate_natural_height = true;
            scrolled.propagate_natural_width = true;
            grid.attach (scrolled, 0, 0, 1, 1);
            tt.changed.connect(() => {
                    redraw();
                });
        } else {
            var nodevs = new Gtk.Label("No tracking devices available");
            nodevs.set_margin_bottom(2);
            nodevs.set_margin_top(2);
            nodevs.set_margin_start(8);
            nodevs.set_margin_end(8);
            grid.attach (nodevs, 0, 0, 1, 1);
        }
        sd_ok.set_hexpand(false);
        sd_ok.set_halign(Gtk.Align.END);
        grid.attach (sd_ok, 0, 1, 1, 1);
        this.add(grid);
    }

    private int populate_view() {
        Gtk.TreeIter iter;
        int n = 0;
        foreach(var s in tt.secdevs) {
            if (s.status != 0) {
                sd_liststore.append (out iter);
                sd_liststore.set (iter,
                                  Column.STATUS, (s.status == TelemTracker.Status.USED),
                                  Column.NAME, s.name,
                                  Column.ALIAS, s.alias,
                                  Column.PMASK, MWSerial.pmask_to_name(s.pmask),
                                  Column.ID,n);
            }
            n++;
        }
        return n;
    }

    public void redraw() {
        sd_liststore.clear();
        populate_view();
    }

    public void run() {
        show_all();
    }
}
