
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

public class MwpDockHelper : Gtk.Window {
    public bool floating {get; private set; default=false;}
    public new bool visible = false;
    public signal void menu_key();
    private Gdl.DockItem di;

	//    public void transient(Gtk.Window w, bool above=false) {
    //}

    private void myreparent(Gdl.DockItem di) {
        var p = di.get_parent();
        p.get_parent().remove(p);
        this.add(p);
    }

    public MwpDockHelper (Gdl.DockItem _di, Gdl.Dock dock, string title, Gtk.Window _w, bool _floater = false) {
        di = _di;
        floating = _floater;
        this.title = title;

        set_transient_for (_w);
		set_keep_above(true);

		window_position = Gtk.WindowPosition.MOUSE;
        //type_hint =  Gdk.WindowTypeHint.DIALOG;

        this.delete_event.connect(() => {
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
        add_accel_group(ag);
		resize(480,320);
        pop_out();
    }

    public void pop_out() {
        if(!di.iconified && floating) {
            di.dock_to (null, Gdl.DockPlacement.FLOATING, 0);
            myreparent(di);
            this.show();
        }
    }
    public new void show() {
        di.show_item();
        show_all();
        visible = true;
    }
    public new void hide() {
        di.iconify_item();
        base.hide();
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


namespace Acme {
	public class FileChooser : Gtk.FileChooserWidget {
		private   Gtk.Window w;
		public signal void response(int id);

		~FileChooser () {
			w.destroy();
		}

		public FileChooser (Gtk.FileChooserAction action, Gtk.Window _w, string? _title = null) {
			w = new Gtk.Window();
			w.set_default_size (1024, 640);
			w.set_transient_for(_w);

			set_action(action);

			var b0 = new Gtk.Button.with_label((action == Gtk.FileChooserAction.SAVE) ? "Save" : "Open");
			b0.clicked.connect(() => {
					response(Gtk.ResponseType.ACCEPT);
				});

			var b1 = new Gtk.Button.with_label("Cancel");
			b1.clicked.connect(() => {
					response(Gtk.ResponseType.CANCEL);

				});

			var header_bar = new Gtk.HeaderBar ();
			if(_title == null) {
				_title = "MWP File Chooser";
			}
			header_bar.set_title (_title);
			header_bar.show_close_button = true;
			header_bar.pack_start (b1);
			header_bar.has_subtitle = false;
			header_bar.pack_end (b0);
			w.set_titlebar (header_bar);
			select_multiple = false;
			Gtk.Box vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
			w.add (vbox);
			vbox.pack_start (this, true, true, 0);

			file_activated.connect(() => {
					response(Gtk.ResponseType.ACCEPT);
				});
		}

		public void run(string? filename = null ) {
			if(get_action() == Gtk.FileChooserAction.SAVE && filename != null)
				set_filename(filename);
			w.show_all();
		}

		public void close() {
			w.close();
		}

		public new void show() {
			w.show_all();
		}
	}
}

namespace Utils {
	public static bool permawarn;

	private uint tid;
	public void warning_box(string warnmsg,
							Gtk.MessageType klass=Gtk.MessageType.WARNING,
							int timeout = 0) {
		var msg = new Gtk.Window();
		tid = 0;

        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		string symb;

		switch (klass) {
		case Gtk.MessageType.ERROR:
			symb = "dialog-error-symbolic";
			break;
		case Gtk.MessageType.INFO:
			symb = "dialog-information-symbolic";
			break;
		case Gtk.MessageType.QUESTION:
			symb = "dialog-question-symbolic";
			break;
		default:
			symb = "dialog-warning-symbolic";
			break;

		}

		var img = new Gtk.Image.from_icon_name(symb, Gtk.IconSize.DIALOG);
		var label = new Gtk.Label(null);
		label.use_markup = true;
		label.label = warnmsg;
		label.margin = 8;
		label.show();


		hbox.pack_start(img, false, false,4);
		hbox.pack_end(label, false, false,2);
		vbox.pack_start(hbox, false, false,4);

		var button = new Gtk.Button.with_label("OK");
		button.hexpand = false;
		button.halign = Gtk.Align.END;
        button.expand = false;

		vbox.pack_end(button, false, false);

		button.clicked.connect(() => {
				if(tid != 0) {
					Source.remove(tid);
				}
                msg.destroy();
			});

        if(timeout > 0 && permawarn == false) {
            Timeout.add_seconds(timeout, () => {
					tid = 0;
                    msg.destroy();
                    return false;;
                });
        }
		msg.set_title("MWP Notice");
		msg.set_keep_above(true);
		msg.add(vbox);
		msg.show_all();
		label.selectable = true;
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

public enum FType {
	UNKNOWN = 0,
	MISSION = 1,
	BBL = 2,
	OTXLOG = 3,
	MWPLOG = 4,
	KMLZ = 5,
	INAV_CLI=6
}

namespace MWPFileType {
	public FType guess_content_type(string uri, out string fn) {
		fn="";
		var ftyp = FType.UNKNOWN;
		try {
			if (uri.has_prefix("file://")) {
				fn = Filename.from_uri(uri);
			} else {
				fn = uri;
			}
			uint8 []buf = new uint8[1024];
			var fs = FileStream.open (fn, "r");
			if (fs != null) {
				if(fs.read (buf) > 0) {
					var mt = GLib.ContentType.guess(fn, buf, null);
					switch (mt) {
					case "application/vnd.mw.mission":
					case "application/vnd.mwp.json.mission":
						ftyp = FType.MISSION;
						break;
					case "application/vnd.blackbox.log":
						ftyp = FType.BBL;
						break;
					case "application/vnd.otx.telemetry.log":
						ftyp = FType.OTXLOG;
						break;
					case "application/vnd.mwp.log":
						ftyp = FType.MWPLOG;
						break;
					case "application/vnd.google-earth.kmz":
					case "application/vnd.google-earth.kml+xml":
						ftyp = FType.KMLZ;
						break;
					default:
						break;
					}

					if(ftyp == FType.UNKNOWN) {
						if(Regex.match_simple ("^(geozone|safehome) ", (string)buf, RegexCompileFlags.MULTILINE|RegexCompileFlags.RAW)) {
							ftyp = FType.INAV_CLI;
							//							} else if(Regex.match_simple ("^safehome ", (string)buf, RegexCompileFlags.MULTILINE|RegexCompileFlags.RAW)) {
							//							ftyp = FType.INAV_CLI;
						} else if(((string)buf).contains("<mission>") || ((string)buf).contains("<MISSION>")) {
							ftyp = FType.MISSION;
						} else if (((string)buf).has_prefix("H Product:Blackbox flight data recorder")) {						ftyp = FType.BBL;
						} else if (((string)buf).has_prefix("{\"type\":\"environment\"")) {
							ftyp = FType.MWPLOG;
						} else if (((string)buf).has_prefix("Date,Time,")) {
							ftyp = FType.OTXLOG;
						} else if (((string)buf).contains("<kml xmlns=\"http://www.opengis.net/kml/2.2\">")) {
							ftyp = FType.KMLZ;
						}
					}
				}
			}
		} catch (Error e) {
			message("regex %s", e.message);
		}
		return ftyp;
	}
}

namespace  UpdateFile {
    private void save(string filename, string key, string keyline) {
        if(FileUtils.test(filename, FileTest.EXISTS)) {
			string keyspc = "%s ".printf(key);
            string []lines = {};
            string s;
            bool written = false;

            FileStream fs = FileStream.open (filename, "r");
            while((s = fs.read_line()) != null)
                lines += s;

            fs = FileStream.open (filename, "w");
            foreach (var l in lines) {
                if(l.has_prefix(keyspc)) {
                    if (written == false) {
						fs.puts(keyline);
                        written = true;
                    }
                } else {
                    fs.puts(l);
                    fs.puts("\n");
                }
            }
            if (written == false) {
				fs.puts(keyline);
			}
        } else {
            FileStream fs = FileStream.open (filename, "w");
            fs.printf("# %s\n", key);
			fs.puts(keyline);
        }
    }
}
