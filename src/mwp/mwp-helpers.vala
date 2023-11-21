
[DBus (name = "org.freedesktop.NetworkManager")]
interface NetworkManager : GLib.Object {
    public signal void StateChanged (uint32 state);
    public abstract uint32 State {owned get;}
}

[DBus (name = "org.gnome.Shell.Screenshot")]
interface ScreenShot : GLib.Object {
    public abstract void ScreenshotArea (int x, int y, int width, int height,
                                          bool flash, string filename,
                                          out bool success,
                                          out string filename_used) throws Error;
}

public enum NMSTATE {
        UNKNOWN=0, ASLEEP=1, CONNECTING=2, CONNECTED=3, DISCONNECTED=4,
        NM_STATE_ASLEEP           = 10,
        NM_STATE_DISCONNECTED     = 20,
        NM_STATE_DISCONNECTING    = 30,
        NM_STATE_CONNECTING       = 40,
        NM_STATE_CONNECTED_LOCAL  = 50,
        NM_STATE_CONNECTED_SITE   = 60,
        NM_STATE_CONNECTED_GLOBAL = 70
}

namespace MWPAlert {
    public const string RED = "bleet.ogg";
    public const string ORANGE = "orange.ogg";
    public const string GENERAL = "beep-sound.ogg";
    public const string SAT = "sat_alert.ogg";
}

public enum RadarSource {
    NONE = 0,
    INAV = 1,
    TELEM = 2,
    MAVLINK = 4,
    SBS = 8,
    M_INAV = (INAV|TELEM),
    M_ADSB = (MAVLINK|SBS),
}

public struct RadarPlot {
    public uint id;
    public string name;
    public double latitude;
    public double longitude;
    public double altitude;
    public uint16 heading;
    public double speed;
    public uint lasttick;
    public uint8 state;
    public uint8 lq;
    public uint8 source;
    public bool posvalid;
	public uint8 alert;
	public DateTime dt;
}

public enum RadarAlert {
	NONE = 0,
	ALERT = 1,
	SET= 2
}

public struct CurrData {
    bool ampsok;
    uint16 centiA;
    uint32 mah;
    uint16 bbla;
    uint64 lmahtm;
    uint16 lmah;
}

public struct Odostats {
	time_t atime;
    double speed;
    double distance;
    double alt;
    double range;
    uint16 amps; // cenitamps
    uint time;
    uint alt_secs;
    uint spd_secs;
    uint rng_secs;
	string cname;
	bool live;
}

public struct VersInfo {
    uint8 mrtype;
    uint8 mvers;
    MWChooser.MWVAR fctype;
    string fc_var;
    string board;
    string name;
    string fc_git;
    uint16 fc_api;
    uint32 fc_vers;
}

public struct TelemStats {
    SerialStats s;
    ulong toc;
    int tot;
    ulong avg;
}

public struct BatteryLevels {
    float cell;
    float limit;
    string colour;
    string audio;
    string label;
    bool reached;
    public BatteryLevels(float _cell, string? _colour, string? _audio, string? _label) {
        cell = _cell;
        limit = 0f;
        colour = _colour;
        audio = _audio;
        label = _label;
        reached = false;
    }
}

public struct MapSize {
    double width;
    double height;
}

public struct FakeOffsets {
    double dlat;
    double dlon;
    bool faking;
}

public class VCol {
    public BatteryLevels [] levels = {
        BatteryLevels(3.7f, "volthigh", null, null),
        BatteryLevels(3.57f, "voltmedium", null, null),
        BatteryLevels(3.47f, "voltlow", MWPAlert.ORANGE, null),
        BatteryLevels(3.0f,  "voltcritical", MWPAlert.RED, null),
        BatteryLevels(2.0f, "voltundef", null, "n/a")
    };
}

public struct MavPOSDef {
    uint16 minval;
    uint16 maxval;
    Craft.Special ptype;
    uint8 chan;
    uint8 set;
}

public class PosFormat : GLib.Object {
    public static string lat(double _lat, bool dms) {
        if(dms == false)
            return "%.6f".printf(_lat);
        else
            return position(_lat, "%02d:%02d:%04.1f%c", "NS");
    }

    public static string lon(double _lon, bool dms) {
        if(dms == false)
            return "%.6f".printf(_lon);
        else
            return position(_lon, "%03d:%02d:%04.1f%c", "EW");
    }

    public static string pos(double _lat, double _lon, bool dms) {
        if(dms == false)
            return "%.6f %.6f".printf(_lat,_lon);
        else {
            var slat = lat(_lat,dms);
            var slon = lon(_lon,dms);
            StringBuilder sb = new StringBuilder(slat);
            sb.append_c(' ');
            sb.append(slon);
            return sb.str;
        }
    }

    private static string position(double coord, string fmt, string ind) {
        var neg = (coord < 0.0);
        var ds = Math.fabs(coord);
        int d = (int)ds;
        var rem = (ds-d)*3600.0;
        int m = (int)rem/60;
        double s = rem - m*60;
        if ((int)s*10 == 600) {
            m+=1;
            s = 0;
        }
        if (m == 60) {
            m = 0;
            d+=1;
        }
        var q = (neg) ? ind.get_char(1) : ind.get_char(0);
        return fmt.printf((int)d,(int)m,s,q);
    }
}

public class MonoFont : Object {
    public static void apply(Gtk.Widget w) {
		var lsc = w.get_style_context();
		try {
			var css1 = new Gtk.CssProvider ();
			css1.load_from_data(".monolabel {font-family: monospace;}");
			lsc.add_provider(css1, 801);
			lsc.add_class("monolabel");
		} catch (Error e) {
			stderr.printf("label context %s\n", e.message);
		}
    }
}

public class MWPCursor : GLib.Object {
    private static void set_cursor(Gtk.Widget widget, Gdk.CursorType? cursor_type) {
        Gdk.Window gdk_window = widget.get_window();
        if (cursor_type != null)
            gdk_window.set_cursor(new Gdk.Cursor.for_display(widget.get_display(),
                                                             cursor_type));
        else
            gdk_window.set_cursor(null);
    }

    public static void set_busy_cursor(Gtk.Widget widget) {
        set_cursor(widget, Gdk.CursorType.WATCH);
    }

    public static void set_normal_cursor(Gtk.Widget widget) {
        set_cursor(widget, null);
    }
}

public class MwpDockHelper : Object {
    private Gtk.Window wdw = null;
    public bool floating {get; private set; default=false;}
    public bool visible = false;
    public signal void menu_key();
    private Gdl.DockItem di;

    public void transient(Gtk.Window w, bool above=false) {
        wdw.set_keep_above(above);
        wdw.set_transient_for (w);
    }

    private void myreparent(Gdl.DockItem di, Gtk.Window w) {
        var p = di.get_parent();
        p.get_parent().remove(p);
        w.add(p);
    }

    public MwpDockHelper (Gdl.DockItem _di, Gdl.Dock dock, string title, bool _floater = false) {
        di = _di;
        floating = _floater;
        wdw = new Gtk.Window();
        wdw.title = title;
        wdw.resize(480,320);
        wdw.window_position = Gtk.WindowPosition.MOUSE;
        wdw.type_hint =  Gdk.WindowTypeHint.DIALOG;

        pop_out();

        wdw.delete_event.connect(() => {
                di.iconify_item();
                return true;
            });

        di.dock_drag_end.connect(() => {
                if(di.get_toplevel() == dock) {
                    floating = false;
                    hide();
                } else {
                    floating = true;
                    pop_out();
                }
            });
        di.hide.connect(() => {
                hide();
            });

        di.show.connect(() => {
                pop_out();
            });
        var ag = new Gtk.AccelGroup();
        ag.connect(Gdk.Key.F3, 0, 0, (a,o,k,m) => {
                menu_key();
                return true;
            });
        wdw.add_accel_group(ag);
    }
    public void pop_out() {
        if(!di.iconified && floating) {
            di.dock_to (null, Gdl.DockPlacement.FLOATING, 0);
            myreparent(di,wdw);
            show();
        }
    }
    public void show() {
        di.show_item();
        wdw.show_all();
        visible = true;
    }
    public void hide() {
        di.iconify_item();
        wdw.hide();
        visible = false;
    }
}

namespace CRSF {
	const uint8 GPS_ID = 0x02;
	const uint8 VARIO_ID = 0x07;
	const uint8 BAT_ID = 0x08;
	const uint8 ATTI_ID = 0x1E;
	const uint8 FM_ID = 0x21;
	const uint8 DEV_ID = 0x29;
	const uint8 LINKSTATS_ID = 0x14;
	const double ATTITODEG = (57.29578 / 10000.0);

	struct Teledata {
		double lat;
		double lon;
		int heading;
		int speed;
		int alt;
		int vario;
		uint8 nsat;
		uint8 fix;
		int16 pitch;
		int16 roll;
		int16 yaw;
		double volts;
		uint16 rssi;
		bool setlab;
	}
	Teledata teledata;

	uint8 * deserialise_be_u24(uint8* rp, out uint32 v) {
        v = (*(rp) << 16 |  (*(rp+1) << 8) | *(rp+2));
        return rp + 3*sizeof(uint8);
	}
}

namespace SportDev {
	bool active;
    int32 lat;
    int32 lon;
    double cse;
    double spd;
    int32 alt;
    double galt;
    uint16 rhdop;
    int16 pitch;
    int16 roll;
    uint8 fix;
    uint8 sats;
    uint8 flags;
    double ax;
    double ay;
    double az;
    uint16 range;
    uint16 rssi;
    int16 vario;
    double volts;
}

namespace Utils {
	public static bool permawarn;
	public void warning_box(string warnmsg,
							Gtk.MessageType klass=Gtk.MessageType.WARNING,
							int timeout = 0) {
        var msg = new Gtk.MessageDialog.with_markup (null, 0, klass,
                                                     Gtk.ButtonsType.OK, warnmsg, null);

        var bin = msg.get_message_area() as Gtk.Container;
        var glist = bin.get_children();
		//        glist.foreach((i) => {
		for(unowned GLib.List<weak Gtk.Widget> lp = glist.first(); lp != null; lp = lp.next) {
			var i = lp.data;
			if (i.get_class().get_name() == "GtkLabel")
				((Gtk.Label)i).set_selectable(true);
		}

        if(timeout > 0 && permawarn == false) {
            Timeout.add_seconds(timeout, () => {
                    msg.destroy();
                    return Source.CONTINUE;
                });
        }
        msg.response.connect ((response_id) => {
                msg.destroy();
            });

        msg.set_title("MWP Notice");
        msg.show();
    }

	public void terminate_plots() {
		try {
			var kplt = new Subprocess(0, "pkill", "gnuplot");
			kplt.wait_check_async.begin(null, (obj,res) => {
					try {
						kplt.wait_check_async.end(res);
					}  catch {}
				});
		} catch {}
	}


}