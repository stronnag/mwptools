/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

using Gtk;
using Gdl;
using Clutter;
using Champlain;
using GtkChamplain;


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

public struct CurrData
{
    bool ampsok;
    uint16 centiA;
    uint32 mah;
    uint16 bbla;
    uint64 lmahtm;
    uint16 lmah;
}

public struct SPORT_INFO
{
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

public struct Odostats
{
    double speed;
    double distance;
    uint time;
    double alt;
    double range;
    uint16 amps; // cenitamps
}

public struct VersInfo
{
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

public struct TelemStats
{
    SerialStats s;
    ulong toc;
    int tot;
    ulong avg;
}

public struct BatteryLevels
{
    float cell;
    float limit;
    string colour;
    string audio;
    string label;
    bool reached;
    public BatteryLevels(float _cell, string? _colour, string? _audio, string? _label)
    {
        cell = _cell;
        limit = 0f;
        colour = _colour;
        audio = _audio;
        label = _label;
        reached = false;
    }
}

public struct MapSize
{
    double width;
    double height;
}

public class Alert
{
    public const string RED = "bleet.ogg";
    public const string ORANGE = "orange.ogg";
    public const string GENERAL = "beep-sound.ogg";
    public const string SAT = "sat_alert.ogg";
}

public class VCol
{
    public BatteryLevels [] levels = {
        BatteryLevels(3.7f, "volthigh", null, null),
        BatteryLevels(3.57f, "voltmedium", null, null),
        BatteryLevels(3.47f, "voltlow", Alert.ORANGE, null),
        BatteryLevels(3.0f,  "voltcritical", Alert.RED, null),
        BatteryLevels(2.0f, "voltundef", null, "n/a")
    };
}

public struct MavPOSDef
{
    uint16 minval;
    uint16 maxval;
    Craft.Special ptype;
    uint8 chan;
    uint8 set;
}



public class PosFormat : GLib.Object
{
    public static string lat(double _lat, bool dms)
    {
        if(dms == false)
            return "%.6f".printf(_lat);
        else
            return position(_lat, "%02d:%02d:%04.1f%c", "NS");
    }

    public static string lon(double _lon, bool dms)
    {
        if(dms == false)
            return "%.6f".printf(_lon);
        else
            return position(_lon, "%03d:%02d:%04.1f%c", "EW");
    }

    public static string pos(double _lat, double _lon, bool dms)
    {
        if(dms == false)
            return "%.6f %.6f".printf(_lat,_lon);
        else
        {
            var slat = lat(_lat,dms);
            var slon = lon(_lon,dms);
            StringBuilder sb = new StringBuilder(slat);
            sb.append_c(' ');
            sb.append(slon);
            return sb.str;
        }
    }

    private static string position(double coord, string fmt, string ind)
    {
        var neg = (coord < 0.0);
        var ds = Math.fabs(coord);
        int d = (int)ds;
        var rem = (ds-d)*3600.0;
        int m = (int)rem/60;
        double s = rem - m*60;
        if ((int)s*10 == 600)
        {
            m+=1;
            s = 0;
        }
        if (m == 60)
        {
            m = 0;
            d+=1;
        }
        var q = (neg) ? ind.get_char(1) : ind.get_char(0);
        return fmt.printf((int)d,(int)m,s,q);
    }
}

public class MWPCursor : GLib.Object
{
    private static void set_cursor(Gtk.Widget widget, Gdk.CursorType? cursor_type)
    {
        Gdk.Window gdk_window = widget.get_window();
        if (cursor_type != null)
            gdk_window.set_cursor(new Gdk.Cursor.for_display(widget.get_display(),
                                                             cursor_type));
        else
            gdk_window.set_cursor(null);
    }

    public static void set_busy_cursor(Gtk.Widget widget)
    {
        set_cursor(widget, Gdk.CursorType.WATCH);
    }

    public static void set_normal_cursor(Gtk.Widget widget)
    {
        set_cursor(widget, null);
    }
}

class MwpDockHelper : Object
{
    private Gtk.Window wdw = null;
    public bool floating {get; private set; default=false;}
    public signal void menu_key();

    public void transient(Gtk.Window w, bool above=false)
    {
        wdw.set_keep_above(above);
        wdw.set_transient_for (w);
    }

    private void myreparent(Gdl.DockItem di, Gtk.Window w)
    {
        var p = di.get_parent();
        p.get_parent().remove(p);
        w.add(p);
    }

    public MwpDockHelper (Gdl.DockItem di, Gdl.Dock dock, string title, bool _floater = false)
    {
        floating = _floater;
        wdw = new Gtk.Window();
        wdw.title = title;
        wdw.resize(480,320);
        wdw.window_position = Gtk.WindowPosition.MOUSE;
        wdw.type_hint =  Gdk.WindowTypeHint.DIALOG;


        if(!di.iconified && floating)
        {
            di.dock_to (null, Gdl.DockPlacement.FLOATING, 0);
            myreparent(di,wdw);
            wdw.show_all();
        }

        wdw.delete_event.connect(() => {
                di.iconify_item();
                return true;
            });

        di.dock_drag_end.connect(() => {
                if(di.get_toplevel() == dock)
                {
                    floating = false;
                    wdw.hide();
                }
                else
                {
                    floating = true;
                    di.dock_to (null, Gdl.DockPlacement.FLOATING, 0);
                    myreparent(di,wdw);
                    wdw.show_all();
                }
            });
        di.hide.connect(() => {
                wdw.hide();
            });

        di.show.connect(() => {
                if(!di.iconified && floating)
                {
                    di.dock_to (null, Gdl.DockPlacement.FLOATING, 0);
                    myreparent(di,wdw);
                    wdw.show_all();
                }
            });
        var ag = new Gtk.AccelGroup();
        ag.connect(Gdk.Key.F3, 0, 0, (a,o,k,m) => {
                menu_key();
                return true;
            });
        wdw.add_accel_group(ag);
    }
}

public class MWPlanner : Gtk.Application {
    private const uint MAXVSAMPLE=12;

    public Builder builder;
    public Gtk.ApplicationWindow window;
    private int window_h = -1;
    private int window_w = -1;
    public  Champlain.View view;
    public MWPMarkers markers;
    private string last_file;
    private ListBox ls;
    private Gtk.SpinButton zoomer;
    private Gtk.Label poslabel;
    private bool pos_is_centre = true;
    public Gtk.Label stslabel;
    public Gtk.Label pointerpos;
    private Gtk.Statusbar statusbar;
    private uint context_id;
    private Gtk.Label elapsedlab;
    private double lx;
    private double ly;
    private Gtk.MenuButton fsmenu_button;
    private string[] dockmenus;

    private Gtk.Button arm_warn;
    private Gtk.ToggleButton wp_edit_button;
    private bool wp_edit = false;
    private bool beep_disabled = false;

    public static MWPSettings conf;
    private MWSerial msp;
    private MWSerial fwddev;
    private Gtk.Button conbutton;
    private Gtk.ComboBoxText dev_entry;
    private Gtk.Label verlab;
    private Gtk.Label fmodelab;
    private Gtk.Label validatelab;
    private Gtk.Spinner armed_spinner;
    private Gtk.Label typlab;
    private Gtk.Label gpslab;

    private int nsampl = 0;
    private float[] vbsamples;

    private Gtk.Label sensor_sts[6];
    private uint32 capability;
    private uint spktid;
    private uint upltid;
    private Craft craft;
    private bool follow = false;
    private bool prlabel = false;
    private bool centreon = false;
    private bool naze32 = false;
    private bool mission_eeprom = false;
    private GtkChamplain.Embed embed;
    private PrefsDialog prefs;
    private SwitchDialog swd;
    private SetPosDialog setpos;
    private Gtk.AboutDialog about;
    private BBoxDialog bb_runner;
    private NavStatus navstatus;
    private RadioStatus radstatus;
    private NavConfig navconf;
    private MapSourceDialog msview;
    private MapSeeder mseed;
    private TelemetryStats telemstatus;
    private GPSInfo gpsinfo;
    private ArtWin art_win;
    private FlightBox fbox;
    private DirnBox dbox;
    private WPMGR wpmgr;
    private MissionItem[] wp_resp;
    private string boxnames = null;
    private static string mission;
    private static string kmlfile;
    private static string serial;
    private static bool autocon;
    private int autocount = 0;
    private uint8 last_wp_pts =0;

    private static bool mkcon = false;
    private static bool ignore_sz = false;
    private static bool nopoll = false;
    private static bool rawlog = false;
    private static bool norotate = false; // workaround for Ubuntu & old champlain
    private static bool no_trail = false;
    private static bool no_max = false;
    private static bool force_mag = false;
    private static bool force_nc = false;
    private static bool force4 = false;
    private static bool chome= false;
    private static string mwoptstr;
    private static string llstr=null;
    private static string layfile=null;
    private static bool asroot = false;

    private MWChooser.MWVAR mwvar=MWChooser.MWVAR.AUTO;
    private uint8 vwarn1;
    private int licol = -1;
    public  DockItem[] dockitem;
    private Gtk.CheckButton audio_cb;
    private Gtk.CheckButton autocon_cb;
    private Gtk.CheckButton logb;
    private bool audio_on;
    private uint8 sflags = 0;
    private uint8 nsats = 0;
    private uint8 _nsats = 0;
    private uint8 larmed = 0;
    private bool wdw_state = false;
    private time_t armtime;
    private time_t duration = 0;
    private time_t last_dura;
    private time_t pausetm;
    private uint32 rtcsecs = 0;

    private uint8 armed = 0;
    private uint8 dac = 0;
    private bool gpsfix;

    private Thread<int> thr;
    private bool xlog;
    private bool xaudio;
    private int[] playfd;
    private ReplayThread robj;
    private int replayer = 0;
    private Pid child_pid;
    private MSP.Cmds[] requests = {};
    private MSP.Cmds msp_get_status = MSP.Cmds.STATUS;
    private uint32 xarm_flags=0xffff;
    private int tcycle = 0;
    private SERSTATE serstate = SERSTATE.NONE;

    private bool rxerr = false;

    private uint64 acycle;
    private uint64 anvals;
    private uint64 xbits = 0;
    private uint8 api_cnt;
    private uint8 icount = 0;
    private bool usemag = false;
    private int16 mhead;
    public static string exstr;

    private bool have_vers;
    private bool have_misc;
    private bool have_api;
    private bool have_status;
    private bool have_wp;
    private bool have_nc;
    private bool have_fcv;
    private bool have_fcvv;
    private bool vinit;
    private bool need_preview;
    private bool xfailsafe = false;

    private uint8 gpscnt = 0;
    private uint8 want_special = 0;
    private uint8 last_ltmf = 0;
    private uint8 mavc = 0;
    private uint16 mavsensors = 0;
    private MavPOSDef[] mavposdef;
    private bool force_mav = false;
    private bool have_mspradio = false;
    private uint16 sensor;
    private uint16 xsensor = 0;
    private uint8 profile = 0;
    private double clat = 0.0;
    private double clon = 0.0;

    private MwpDockHelper mwpdh;

        /* for jump protection */
    private double xlon = 0;
    private double xlat = 0;

    private bool use_gst = false;
    private bool inav = false;
    private bool sensor_alm = false;
    private uint8 xs_state = 0;

    private uint16  rhdop = 10000;
    private uint gpsintvl = 0;
    private bool telem = false;
    private uint8 wp_max = 0;

    private uint16 nav_wp_safe_distance = 10000;
    private uint16 inav_max_eph_epv = 1000;

    private bool need_mission = false;
    private Clutter.Text clutextr;
    private Clutter.Text clutextg;
    private Clutter.Text clutextd;
    private bool map_clean;
    private VCol vcol;
    private Odostats odo;
    private OdoView odoview;
    private uint8 downgrade = 0;
    private uint8 last_nmode = 0;
    private uint8 last_nwp = 0;
    private int wpdist = 0;
    private uint8 msats;
    private MapSize mapsize;

    private string? vname = null;

    private static bool is_wayland = false;
    private static bool use_wayland = false;
    private static bool permawarn = false;

    private uchar hwstatus[9];
    private ModelMap mmap;

    private GPSStatus gps_status;
    private MSP_GPSSTATISTICS gpsstats;
    private int magdt = -1;
    private int magtime=0;
    private int magdiff=0;
    private bool magcheck;

    private bool x_replay_bbox_ltm_rb;
    private bool x_kmz;
    public bool x_plot_elevations_rb {get; private set; default= false;}

    private Array<KmlOverlay> kmls;

    public DevManager devman;

    public struct MQI //: Object
    {
        MSP.Cmds cmd;
        size_t len;
        uint8 *data;
    }

    private MQI lastmsg;
    private Queue<MQI?> mq;

    private enum APIVERS
    {
        mspV2 = 0x0200,
        mixer = 0x0202
    }

    private enum FCVERS
    {
        hasMoreWP = 0x010400,
        hasEEPROM = 0x010600,
        hasTZ = 0x010704,
        hasV2STATUS = 0x010801,
    }

    public enum SERSTATE
    {
        NONE=0,
        NORMAL,
        POLLER,
        TELEM,
        TELEM_SP
    }

    private enum DEBUG_FLAGS
    {
        NONE=0,
        WP = 1,
        INIT=2,
        MSP=4
    }

    private enum SAT_FLAGS
    {
        NONE=0,
        NEEDED = 1,
        URGENT = 2,
        BEEP = 4
    }

    private enum Player
    {
        NONE = 0,
        MWP = 1,
        BBOX = 2,
        FAST_MASK = 4,
        MWP_FAST = 5,
        BBOX_FAST = 6
    }

    public struct Position
    {
        double lat;
        double lon;
        double alt;
    }

    private enum OSD
    {
        show_mission = 1,
        show_dist = 2
    }

    private bool have_home;
    private Position home_pos;
    private Position rth_pos;
    private Position ph_pos;
    private uint64 ph_mask=0;
    private uint64 arm_mask=0;
    private uint64 rth_mask=0;
    private uint64 angle_mask=0;
    private uint64 horz_mask=0;
    private uint64 wp_mask=0;

    private uint no_ofix = 0;

    private TelemStats telstats;
    private LayMan lman;

    public enum NAVCAPS
    {
        NONE=0,
        WAYPOINTS=1,
        NAVSTATUS=2,
        NAVCONFIG=4,
        INAV_MR=8,
        INAV_FW=16
    }

    private NAVCAPS navcap;

    private enum DOCKLETS
    {
        MISSION=0,
        GPS,
        NAVSTATUS,
        VOLTAGE,
        RADIO,
        TELEMETRY,
        ARTHOR,
        FBOX,
        DBOX,
        NUMBER
    }

    private enum MS_Column {
        ID,
        NAME,
        N_COLUMNS
    }

    private enum WPDL {
        IDLE=0,
        VALIDATE = (1<<0),
        REPLACE = (1<<1),
        POLL = (1<<2),
        REPLAY = (1<<3),
        SAVE_EEPROM = (1<<4),
        GETINFO = (1<<5),
        CALLBACK = (1<<6),
        CANCEL = (1<<7)
    }

    private struct WPMGR
    {
        MSP_WP[] wps;
        WPDL wp_flag;
        uint8 npts;
        uint8 wpidx;
    }


    private enum WPFAIL {
        OK=0,
        NO = (1<<0),
        ACT = (1<<1),
        LAT = (1<<2),
        LON = (1<<3),
        ALT = (1<<4),
        P1 = (1<<5),
        P2 = (1<<6),
        P3 = (1<<7),
        FLAG = (1<<8)
    }

    private enum POSMODE
    {
        HOME = 1,
        PH = 2,
        RTH = 4,
        WP = 8,
        ALTH = 16,
        CRUISE =32
    }

    private enum ARMFLAGS
    {
        ARMED                                           = (1 << 2),
        WAS_EVER_ARMED                                  = (1 << 3),
        ARMING_DISABLED_FAILSAFE_SYSTEM                 = (1 << 7),
        ARMING_DISABLED_NOT_LEVEL                       = (1 << 8),
        ARMING_DISABLED_SENSORS_CALIBRATING             = (1 << 9),
        ARMING_DISABLED_SYSTEM_OVERLOADED               = (1 << 10),
        ARMING_DISABLED_NAVIGATION_UNSAFE               = (1 << 11),
        ARMING_DISABLED_COMPASS_NOT_CALIBRATED          = (1 << 12),
        ARMING_DISABLED_ACCELEROMETER_NOT_CALIBRATED    = (1 << 13),
        ARMING_DISABLED_ARM_SWITCH                      = (1 << 14),
        ARMING_DISABLED_HARDWARE_FAILURE                = (1 << 15),
            // Alas, not reported by STATUS_EX
        ARMING_DISABLED_BOXFAILSAFE                     = (1 << 16),
        ARMING_DISABLED_BOXKILLSWITCH                   = (1 << 17),
        ARMING_DISABLED_RC_LINK                         = (1 << 18),
        ARMING_DISABLED_THROTTLE                        = (1 << 19),
        ARMING_DISABLED_CLI                             = (1 << 20),
        ARMING_DISABLED_CMS_MENU                        = (1 << 21),
        ARMING_DISABLED_OSD_MENU                        = (1 << 22),
        ARMING_DISABLED_ROLLPITCH_NOT_CENTERED          = (1 << 23),
        ARMING_DISABLED_SERVO_AUTOTRIM                  = (1 << 24),
        ARMING_DISABLED_OOM                             = (1 << 25),
        ARMING_DISABLED_INVALID_SETTING                 = (1 << 26),
        ARMING_DISABLED_OTHER                           = (1 << 27)
    }

    private string? [] arm_fails =
    {
        null, null, "Armed",null, /*"Ever Armed"*/ null,null,null,
        "Failsafe", "Not level","Calibrating","Overload",
        "Navigation unsafe", "Compass cal", "Acc cal", "Arm switch", "H/W fail",
        "Box failsafe", "Box killswitch", "RC Link", "Throttle", "CLI",
        "CMS Menu", "OSD Menu", "Roll/Pitch", "Servo Autotrim", "Out of memory",
        "Settings", "Other"
    };

    private enum SENSOR_STATES
    {
        None = 0,
        OK = 1,
        UNAVAILABLE = 2,
        UNHEALTHY = 3
    }

    private string [] health_states =
    {
        "None", "OK", "Unavailable", "Unhealthy"
    };

    private string[] sensor_names =
    {
        "Gyro", "Accelerometer", "Compass", "Barometer",
        "GPS", "RangeFinder", "Pitot", "OpticalFlow"
    };

    private string [] disarm_reason =
    {
        "None", "Timeout", "Sticks", "Switch_3d", "Switch",
            "Killswitch", "Failsafe", "Navigation" };

    private const string[] failnames = {"WPNO","ACT","LAT","LON","ALT","P1","P2","P3","FLAG"};

    private const uint TIMINTVL=100;
    private const uint BEATINTVL=(60000/TIMINTVL);
    private const uint STATINTVL=(1000/TIMINTVL);
    private const uint NODATAINTVL=(5000/TIMINTVL);
    private const uint SATINTVL=(10000/TIMINTVL);
    private const uint USATINTVL=(2000/TIMINTVL);
    private const uint UUSATINTVL=(4000/TIMINTVL);
    private const uint RESTARTINTVL=(30000/TIMINTVL);
    private const uint MAVINTVL=(2000/TIMINTVL);
    private const uint CRITINTVL=(3000/TIMINTVL);

    private enum SATS
    {
        MINSATS = 6
    }

    private enum FWDS
    {
        NONE=0,
        LTM=1,
        minLTM=2,
        minMAV=3,
        ALL=4
    }

    private const double RAD2DEG = 57.29578;

    private Timer lastp;
    private uint nticks = 0;
    private uint lastm = 0;
    private uint lastrx = 0;
    private uint last_ga = 0;
    private uint last_gps = 0;
    private uint last_crit = 0;
    private uint last_tm = 0;
    private uint lastok = 0;
    private uint last_an = 0;
    private static bool offline = false;
    private static string rfile = null;
    private static string bfile = null;
    private static string forward_device = null;
    private static string sport_device = null;
    private static int dmrtype=0;
    private static DEBUG_FLAGS debug_flags = 0;
    private static VersInfo vi ={0};
    private static bool set_fs;
    private static bool show_vers = false;
    private static int stack_size = 0;
    private static int mod_points = 0;
    public static unowned string ulang;
    private static bool ignore_3dr = false;
    private static string? exvox = null;
    private static string rrstr;
    private static bool nofsmenu = false;
    private int nrings = 0;
    private double ringint = 0;
    private bool replay_paused;
    private SPORT_INFO spi;
    private CurrData curr;

    private MwpServer mss=null;
    private uint8 spapi =  0;

    public const string[] SPEAKERS =  {"none", "espeak","speechd","flite","external"};
    public enum SPEAKER_API
    {
        NONE=0,
        ESPEAK=1,
        SPEECHD=2,
        FLITE=3,
        EXTERNAL=4,
        COUNT=5
    }

    private const Gtk.TargetEntry[] targets = {
        {"text/uri-list",0,0}
    };

    const OptionEntry[] options = {
        { "mission", 'm', 0, OptionArg.STRING, out mission, "Mission file", "file-name"},
        { "serial-device", 's', 0, OptionArg.STRING, out serial, "Serial device", "device_name"},
        { "device", 'd', 0, OptionArg.STRING, out serial, "Serial device", "device-name"},
        { "flight-controller", 'f', 0, OptionArg.STRING, out mwoptstr, "mw|mwnav|bf|cf", "fc-name"},
        { "connect", 'c', 0, OptionArg.NONE, out mkcon, "connect to first device (does not set auto flag)", null},
        { "auto-connect", 'a', 0, OptionArg.NONE, out autocon, "auto-connect to first device (sets auto flag)", null},
        { "no-poll", 'N', 0, OptionArg.NONE, out nopoll, "don't poll for nav info", null},
        { "no-trail", 'T', 0, OptionArg.NONE, out no_trail, "don't display GPS trail", null},
        { "raw-log", 'r', 0, OptionArg.NONE, out rawlog, "log raw serial data to file", null},
        { "ignore-sizing", 0, 0, OptionArg.NONE, out ignore_sz, "ignore minimum size constraint", null},
        { "full-screen", 0, 0, OptionArg.NONE, out set_fs, "open full screen", null},
        { "ignore-rotation", 0, 0, OptionArg.NONE, out norotate, "ignore vehicle icon rotation on old libchamplain", null},
        { "dont-maximise", 0, 0, OptionArg.NONE, out no_max, "don't maximise the window", null},
        { "force-mag", 0, 0, OptionArg.NONE, out force_mag, "force mag for vehicle direction", null},
        { "force-nav", 0, 0, OptionArg.NONE, out force_nc, "force nav capaable", null},
        { "layout", 'l', 0, OptionArg.STRING, out layfile, "Layout name", null},
        { "force-type", 't', 0, OptionArg.INT, out dmrtype, "Model type", "type-code_no"},
        { "force4", '4', 0, OptionArg.NONE, out force4, "Force ipv4", null},
        { "ignore-3dr", '3', 0, OptionArg.NONE, out ignore_3dr, "Ignore 3DR RSSI info", null},
        { "centre-on-home", 'H', 0, OptionArg.NONE, out chome, "Centre on home", null},
        { "debug-flags", 0, 0, OptionArg.INT, out debug_flags, "Debug flags (mask)", null},
        { "replay-mwp", 'p', 0, OptionArg.STRING, out rfile, "replay mwp log file", "file-name"},
        { "replay-bbox", 'b', 0, OptionArg.STRING, out bfile, "replay bbox log file", "file-name"},
        { "centre", 0, 0, OptionArg.STRING, out llstr, "Centre position", "position"},
        { "offline", 0, 0, OptionArg.NONE, out offline, "force offline proxy mode", null},
        { "n-points", 'S', 0, OptionArg.INT, out stack_size, "Number of points shown in GPS trail", "N"},
        { "mod-points", 'M', 0, OptionArg.INT, out mod_points, "Modulo points to show in GPS trail", "N"},

        { "rings", 0, 0, OptionArg.STRING, out rrstr, "Range rings (number, interval(m)), e.g. --rings 10,20", "number,interval"},
        { "voice-command", 0, 0, OptionArg.STRING, out exvox, "External speech command", "command string"},
        { "version", 'v', 0, OptionArg.NONE, out show_vers, "show version", null},
        { "wayland", 0, 0, OptionArg.NONE, out use_wayland, "force wayland (if available)", null},
        { "really-really-run-as-root", 0, 0, OptionArg.NONE, out asroot, "no reason to ever use this", null},
        { "forward-to", 0, 0, OptionArg.STRING, out forward_device, "forward telemetry to", "device-name"},
        { "smartport", 0, 0, OptionArg.STRING, out sport_device, "smartport device", "device-name"},
        {"perma-warn", 0, 0, OptionArg.NONE, out permawarn, "info dialogues never time out", null},
        {"fsmenu", 0, 0, OptionArg.NONE, out nofsmenu, "use a menu bar in full screen (vice a menu button)", null},
        { "kmlfile", 'k', 0, OptionArg.STRING, out kmlfile, "KML file", "file-name"},
        {null}
    };

    void show_dock_id (DOCKLETS id, bool iconify=false)
    {
        if(dockitem[id].is_closed() && !dockitem[id].is_iconified())
        {
            dockitem[id].show();
            if(iconify)
                dockitem[id].iconify_item();
        }
        update_dockmenu(id);
    }

    bool item_visible(DOCKLETS id)
    {
        return !dockitem[id].is_closed();
    }

    private void set_dock_menu_status()
    {
        for(var id = DOCKLETS.MISSION; id < DOCKLETS.NUMBER; id += 1)
        {
            update_dockmenu(id);
            if(id == DOCKLETS.FBOX &&
               !dockitem[id].is_closed () && !dockitem[id].is_iconified())
            {
                    Idle.add(() => {
                            fbox.check_size();
                            fbox.update(true);
                            return Source.REMOVE;
                        });
            }
        }
    }

    private void update_dockmenu(DOCKLETS id)
    {
        var res = (dockitem[id].is_closed () == dockitem[id].is_iconified());
        set_menu_state(dockmenus[id], !res);
    }

    MWPlanner ()
    {
        Object(application_id: "mwp.application", flags: ApplicationFlags.FLAGS_NONE);
    }

    public void cleanup()
    {
        if(msp.available)
            msp.close();

        if(conf.atexit != null)
            try {
                Process.spawn_command_line_sync (conf.atexit);
            } catch {}
    }


    private void handle_replay_pause()
    {
        int signum;
        magcheck = false;

        if(replay_paused)
        {
            signum = MwpSignals.Signal.CONT;
            time_t now;
            time_t (out now);
            armtime += (now - pausetm);
        }
        else
        {
            time_t (out pausetm);
            signum = MwpSignals.Signal.STOP;
        }
        replay_paused = !replay_paused;
        if((replayer & Player.BBOX) == Player.BBOX)
        {
            Posix.kill(child_pid, signum);
        }
        else
        {
            if(thr != null)
                robj.pause(replay_paused);
        }
    }

    private void set_menu_state(string action, bool state)
    {
        var ac = window.lookup_action(action) as SimpleAction;
        ac.set_enabled(state);
    }

    public SERSTATE get_serstate()
    {
        return serstate;
    }

    public void set_serstate(SERSTATE s = SERSTATE.NONE)
    {
        lastrx = lastok = nticks;
        serstate = s;
        resend_last();
    }

    private string? mwp_check_virtual()
    {
        string hyper = null;
        try {
            string[] spawn_args = {"dmesg"};
            int p_stdout;
            Pid child_pid;

            Process.spawn_async_with_pipes (null,
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.DO_NOT_REAP_CHILD |
                                            SpawnFlags.STDERR_TO_DEV_NULL,
                                            null,
                                            out child_pid,
                                            null,
                                            out p_stdout,
                                            null);

            IOChannel chan = new IOChannel.unix_new (p_stdout);
            IOStatus eos;
            string line;
            size_t length = -1;

            try
            {
                for(;;)
                {
                    eos = chan.read_line (out line, out length, null);
                    if(eos == IOStatus.EOF)
                        break;

                    if(line == null || length == 0)
                        continue;

                    var index = line.index_of("Hypervisor");
                    if(index != -1)
                    {
                        hyper = line.substring(index).chomp();
                        break;
                    }
                }
            } catch (IOChannelError e) {}
            catch (ConvertError e) {}
            try { chan.shutdown(false); } catch {}
            Process.close_pid (child_pid);
        } catch (SpawnError e) {}
        return hyper;
    }

    public override void activate ()
    {
        base.startup();
        gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};

        wpmgr = WPMGR();

        vbsamples = new float[MAXVSAMPLE];

        devman = new DevManager();

        hwstatus[0] = 1; // Assume OK

        conf = new MWPSettings();
        conf.read_settings();

        var vstr = mwp_check_virtual();
        if(vstr == null || vstr.length == 0)
            MWPLog.message("No hypervisor detected\n");
        else
            MWPLog.message(vstr);

        {
            string []  ext_apps = {
            conf.blackbox_decode, "replay_bbox_ltm.rb",
            "gnuplot", "mwp-plot-elevations.rb", "unzip" };
            bool appsts[5];
            var i = 0;
            foreach (var s in ext_apps)
            {
                appsts[i] = MWPUtils.exists_on_path(s);
                if (appsts[i] == false)
                    MWPLog.message("Failed to find \"%s\" on PATH\n", s);
                i++;
            }
            x_replay_bbox_ltm_rb = (appsts[0]&&appsts[1]);
            x_plot_elevations_rb = (appsts[2]&&appsts[3]);
            x_kmz = appsts[4];
        }

        pos_is_centre = conf.pos_is_centre;

        mmap = new ModelMap();
        mmap.init();

        spapi = 0;

        if(exvox == null)
        {
            StringBuilder vsb = new StringBuilder();
            if (!MwpMisc.is_cygwin())
            {
                uint8 spapi_mask  = MwpSpeech.get_api_mask();
                if (spapi_mask != 0)
                {
                    for(uint8 j = SPEAKER_API.ESPEAK; j < SPEAKER_API.COUNT; j++)
                    {
                        if(conf.speech_api == SPEAKERS[j] && ((spapi_mask & (1<<(j-1))) != 0))
                        {
                            spapi = j;
                            break;
                        }
                    }
                }
                MWPLog.message("Using speech api %d [%s]\n", spapi, SPEAKERS[spapi]);
            }
            else
            {
                switch(conf.speech_api)
                {
                    case "espeak":
                        vsb.append("espeak");
                        if(conf.evoice.length > 0)
                        {
                            vsb.append(" -v ");
                            vsb.append(conf.evoice);
                        }
                        break;
                    case "speechd":
                        vsb.append("spd-say -e");
                        if(conf.svoice.length > 0)
                        {
                            vsb.append(" -t ");
                            vsb.append(conf.svoice);
                        }
                        break;
                }
                if(vsb.len > 0)
                    exvox = vsb.str;
            }
        }


        if(exvox != null)
        {
            MWPLog.message("Using external speech api [%s]\n", exvox);
        }

        MwpSpeech.set_api(spapi);

        ulang = Intl.setlocale(LocaleCategory.NUMERIC, "");

        if(conf.uilang == "en")
            Intl.setlocale(LocaleCategory.NUMERIC, "C");

        builder = new Builder ();

        if(layfile == null && conf.deflayout != null)
            layfile = conf.deflayout;

        var confdir = GLib.Path.build_filename(Environment.get_user_config_dir(),"mwp");
        try
        {
            var dir = File.new_for_path(confdir);
            dir.make_directory_with_parents ();
        } catch {};

        gpsintvl = conf.gpsintvl / TIMINTVL;

        if(conf.mediap.length == 0)
            use_gst = true;
        else if(conf.mediap == "false" || conf.mediap == "none")
        {
            MWPLog.message("Beeps disabled\n");
            beep_disabled = true;
        }

        if(rrstr != null)
        {
            var parts = rrstr .split(",");
            if(parts.length == 2)
            {
                nrings = int.parse(parts[0]);
                ringint = double.parse(parts[1]);
            }
        }

        string[]ts={"mwp.ui","menubar.ui"};
        foreach(var fnm in ts)
        {
            var fn = MWPUtils.find_conf_file(fnm);
            if (fn == null)
            {
                MWPLog.message ("No UI definition file\n");
                quit();
            }
            else
            {
                try
                {
                    builder.add_from_file (fn);
                } catch (Error e) {
                    MWPLog.message ("Builder: %s\n", e.message);
                    quit();
                }
            }
        }

        var cvers = Champlain.VERSION_S;
        if (cvers == "0.12.11")
        {
            MWPLog.message("libchamplain 0.12.11 may not draw maps at scale > 16\n");
            MWPLog.message("Consider downgrading, upgrading or building from source\n");
        }
        else
            MWPLog.message("libchamplain %s\n", Champlain.VERSION_S);

        if(conf.ignore_nm == false)
        {
            if(offline == false)
            {
                try {
                    NetworkManager nm = Bus.get_proxy_sync (BusType.SYSTEM,
                                                            "org.freedesktop.NetworkManager",
                                                            "/org/freedesktop/NetworkManager");
                    NMSTATE istate = (NMSTATE)nm.State;
                    if(!(istate != NMSTATE.NM_STATE_CONNECTED_GLOBAL ||
                         istate != NMSTATE.UNKNOWN))
                    {
                        offline = true;
                        MWPLog.message("Forcing proxy offline [%s]\n",
                                       istate.to_string());
                    }
                } catch {}
            }
        }

        if(conf.atstart != null)
        {
            try {
                Process.spawn_command_line_async(conf.atstart);
            } catch {};
        }

        MapSource [] msources = {};
        string msfn = null;
        if(conf.map_sources != null)
            msfn = MWPUtils.find_conf_file(conf.map_sources);
        msources =   JsonMapDef.read_json_sources(msfn,offline);

        builder.connect_signals (null);
        window = builder.get_object ("window1") as Gtk.ApplicationWindow;
        this.add_window (window);
        window.set_application (this);
        window.window_state_event.connect( (e) => {
                wdw_state = ((e.new_window_state & Gdk.WindowState.FULLSCREEN) != 0);
                if(wdw_state)
                    if(nofsmenu)
                        window.set_show_menubar(true);
                    else
                        fsmenu_button.show();
                else
                    if(nofsmenu)
                        window.set_show_menubar(false);
                    else
                        fsmenu_button.hide();
            return false;
        });


        dev_entry = builder.get_object ("comboboxtext1") as Gtk.ComboBoxText;

        string icon=null;
        try {
            icon = MWPUtils.find_conf_file("mwp_icon.svg");
            window.set_icon_from_file(icon);
        } catch {};

        arm_warn = builder.get_object ("arm_warn") as Gtk.Button;
        wp_edit_button = builder.get_object ("wp_edit_button") as Gtk.ToggleButton;
        sensor_sts[0] = builder.get_object ("gyro_sts") as Gtk.Label;
        sensor_sts[1] = builder.get_object ("acc_sts") as Gtk.Label;
        sensor_sts[2] = builder.get_object ("baro_sts") as Gtk.Label;
        sensor_sts[3] = builder.get_object ("mag_sts") as Gtk.Label;
        sensor_sts[4] = builder.get_object ("gps_sts") as Gtk.Label;
        sensor_sts[5] = builder.get_object ("sonar_sts") as Gtk.Label;

        wp_edit_button.clicked.connect(() =>
        {
            wp_edit = !wp_edit;
            wp_edit_button.label= (wp_edit) ? "✔" : "";
            wp_edit_button.tooltip_text = ("Enable / disable the addition of WPs by clicking on the map (%sabled)".printf((wp_edit) ? "en" : "dis"));
        });

        arm_warn.clicked.connect(() =>
            {
                StringBuilder sb = new StringBuilder();
                if((xarm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0)
                {
                    sb.append("<b>Arm Status</b>\n");
                    string arm_msg = get_arm_fail(xarm_flags,'\n');
                    sb.append(arm_msg);
                }

                if(hwstatus[0] == 0)
                {
                    sb.append("<b>Hardware Status</b>\n");
                    for(var i = 0; i < 8; i++)
                    {
                        uint ihs = hwstatus[i+1];
                        string shs = (ihs < health_states.length) ?
                            health_states[ihs] : "*broken*";
                        sb.append_printf("%s : %s\n", sensor_names[i], shs);
                    }
                }

                var pop = new Gtk.Popover(arm_warn);
                pop.position = Gtk.PositionType.BOTTOM;
                Gtk.Label label = new Gtk.Label(sb.str);
                label.set_use_markup (true);
                label.set_line_wrap (true);
                label.margin = 8;
                pop.add(label);
                pop.show_all();
            });

        zoomer = builder.get_object ("spinbutton1") as Gtk.SpinButton;

        var mm = builder.get_object ("menubar") as MenuModel;
        Gtk.MenuBar  menubar = new MenuBar.from_model(mm);
        this.set_menubar(mm);
        var hb = builder.get_object ("hb") as HeaderBar;
        window.set_show_menubar(false);
        hb.pack_start(menubar);

        fsmenu_button = builder.get_object("fsmenu_button") as Gtk.MenuButton;

        Gtk.Image img = new Gtk.Image.from_icon_name("open-menu-symbolic",
                                                     Gtk.IconSize.BUTTON);
        fsmenu_button.add(img);
        fsmenu_button.set_menu_model(mm);

        var aq = new GLib.SimpleAction("quit",null);
        aq.activate.connect(() => {
                conf.save_floating (mwpdh.floating);
                lman.save_config();
                remove_window(window);
            });
        this.add_action(aq);

        window.destroy.connect(() => {
                cleanup();
                remove_window(window);
                this.quit();
            });

        mseed = new MapSeeder(builder,window);
        var shortcuts = builder.get_object ("shortcut-dialog") as Gtk.Dialog;
        shortcuts.set_transient_for(window);
        var shortclose = builder.get_object ("shorts-close") as Gtk.Button;
        shortcuts.delete_event.connect (() => {
                shortcuts.hide();
                return true;
            });

        shortclose.clicked.connect (() => {
                shortcuts.hide();
            });

        msview = new MapSourceDialog(builder, window);
        setpos = new SetPosDialog(builder, window);
        var places = new Places();
        var pls = places.get_places(conf.latitude, conf.longitude);
        setpos.load_places(pls,conf.dms);
        setpos.new_pos.connect((la, lo) => {
                map_centre_on(la, lo);
            });

        navconf = new NavConfig(window, builder);
        bb_runner = new BBoxDialog(builder, window, conf.blackbox_decode,
                                   conf.logpath);

        bb_runner.set_tz_tools(conf.geouser, conf.zone_detect);

        bb_runner.new_pos.connect((la, lo) => {
               try_centre_on(la, lo);
            });

        bb_runner.rescale.connect((llx, lly, urx,ury) => {
                if(replayer != Player.NONE)
                {
                    Champlain.BoundingBox bbox = new Champlain.BoundingBox();
                    bbox.left = llx;
                    bbox.bottom = lly;
                    bbox.right = urx;
                    bbox.top = ury;
                    var z = guess_appropriate_zoom(bbox);
                    view.zoom_level = z;
                    view.ensure_visible(bbox, false);
                }
            });

        dockmenus = new string[DOCKLETS.NUMBER];

        dockmenus[DOCKLETS.MISSION] = "mission-list";
        dockmenus[DOCKLETS.GPS] = "gps-status";
        dockmenus[DOCKLETS.NAVSTATUS] = "nav-status";
        dockmenus[DOCKLETS.VOLTAGE] = "bat-mon";
        dockmenus[DOCKLETS.RADIO] = "radio-status";
        dockmenus[DOCKLETS.TELEMETRY] =  "tel-stats";
        dockmenus[DOCKLETS.ARTHOR] = "art-hor";
        dockmenus[DOCKLETS.FBOX] =  "flight-view";
        dockmenus[DOCKLETS.DBOX] =  "direction-view";

        embed = new GtkChamplain.Embed();

        gps_status = new GPSStatus(builder, window);

        var saq = new GLib.SimpleAction("file-open",null);
        saq.activate.connect(() => {
                on_file_open();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("menu-save",null);
        saq.activate.connect(() => {
                on_file_save();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("menu-save-as",null);
        saq.activate.connect(() => {
                on_file_save_as();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("prefs",null);
        saq.activate.connect(() => {
                if(prefs.run_prefs(ref conf) == 1001)
                {
                    build_deventry();
                    if(conf.speakint == 0)
                        conf.speakint = 15;
                    audio_cb.sensitive = true;
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("centre-on",null);
        saq.activate.connect(() => {
                setpos.get_position();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("defloc",null);
        saq.activate.connect(() => {
                conf.latitude = view.get_center_latitude();
                conf.longitude = view.get_center_longitude();
                conf.zoom = view.get_zoom_level();
                conf.save_settings();
                pls[0].lat = conf.latitude;
                pls[0].lon = conf.longitude;
                setpos.load_places(pls,conf.dms);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("recentre",null);
        saq.activate.connect(() => {
                centre_mission(ls.to_mission(), true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("mission-info",null);
        saq.activate.connect(() => {
                if(msp.available && (serstate == SERSTATE.POLLER ||
                                     serstate == SERSTATE.NORMAL))
                {
                    wpmgr.wp_flag |= WPDL.GETINFO;
                    queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("terminal",null);
        saq.activate.connect(() => {
                if(msp.available && armed == 0)
                {
                    mq.clear();
                    serstate = SERSTATE.NONE;
                    CLITerm t = new CLITerm(window);
                    t.configure_serial(msp);
                    t.show_all ();
                    t.on_exit.connect(() => {
                            serial_doom(conbutton);
                            Timeout.add_seconds(2, () => {
                                    connect_serial();
                                    return !msp.available;
                                });
                        });
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("reboot",null);
        saq.activate.connect(() => {
                if(msp.available && armed == 0)
                {
                    queue_cmd(MSP.Cmds.REBOOT,null, 0);
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("audio",null);
        saq.activate.connect(() => {
                var aon = audio_cb.active;
                if(aon == false)
                {
                    audio_on = true;
                    start_audio(false);
                }
                navstatus.audio_test();

                if(aon == false)
                {
                    Timeout.add(8000, () => {
                            if(audio_cb.active == false)
                            {
                                stop_audio();
                            }
                            return false;
                        });
                }
            });
        window.add_action(saq);


        saq = new GLib.SimpleAction("map-source",null);
        saq.activate.connect(() => {
                var map_source_factory = Champlain.MapSourceFactory.dup_default();
                var sources =  map_source_factory.get_registered();
                foreach (Champlain.MapSourceDesc sr in sources)
                {
                    if(view.map_source.get_id() == sr.get_id())
                    {
                        msview.show_source(
                            sr.get_name(),
                            sr.get_id(),
                            sr.get_uri_format (),
                            sr.get_min_zoom_level(),
                            sr.get_max_zoom_level());
                        break;
                    }
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("seed-map",null);
        saq.activate.connect(() => {
                mseed.run_seeder(view.map_source.get_id(),
                                 (int)zoomer.adjustment.value,
                                 view.get_bounding_box());

            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("gps-stats",null);
        saq.activate.connect(() => {
                if(!gps_status.visible)
                {
                    gps_status.update(gpsstats);
                    gps_status.show();
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("about",null);
        saq.activate.connect(() => {
                about.show_all();
                about.response.connect(() => {
                        about.hide();
                    });
                about.delete_event.connect (() => {
                        about.hide();
                        return true;
                    });
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("upload-mission",null);
        saq.activate.connect(() => {
                upload_mission(WPDL.VALIDATE);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("download-mission",null);
        saq.activate.connect(() => {
                download_mission();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("restore-mission",null);
        saq.activate.connect(() => {
                uint8 zb=0;
                queue_cmd(MSP.Cmds.WP_MISSION_LOAD, &zb, 1);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("store-mission",null);
        saq.activate.connect(() => {
                upload_mission(WPDL.SAVE_EEPROM);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("replay-log",null);
        saq.activate.connect(() => {
                replay_log(true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("load-log",null);
        saq.activate.connect(() => {
                replay_log(false);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("replay-bb",null);
        saq.activate.connect(() => {
                replay_bbox(true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("load-bb",null);
        saq.activate.connect(() => {
                replay_bbox(false);
            });
        window.add_action(saq);


        saq = new GLib.SimpleAction("stop-replay",null);
        saq.activate.connect(() => {
                stop_replayer();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("kml-load",null);
        saq.activate.connect(() => {
                kml_load_dialog();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("kml-remove",null);
        saq.activate.connect(() => {
                kml_remove_dialog();
            });
        window.add_action(saq);

        set_menu_state("kml-remove", false);

        saq = new GLib.SimpleAction("navconfig",null);
        saq.activate.connect(() => {
                navconf.show();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("flight-stats",null);
        saq.activate.connect(() => {
                odoview.display(odo, false);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("layout-save",null);
        saq.activate.connect(() => {
                lman.save();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("layout-restore",null);
        saq.activate.connect(() => {
                lman.restore();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("mission-list",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.MISSION, false);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("gps-status",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.GPS, true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("nav-status",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.NAVSTATUS,true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("bat-mon",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.VOLTAGE, true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("radio-status",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.RADIO, true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("tel-stats",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.TELEMETRY, true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("art-hor",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.ARTHOR, true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("flight-view",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.FBOX, true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("direction-view",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.DBOX, true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("keys",null);
        saq.activate.connect(() => {
                shortcuts.show_all();
            });
        window.add_action(saq);

        reboot_status();

        set_replay_menus(true);
        set_menu_state("upload-mission", false);
        set_menu_state("download-mission", false);
        set_menu_state("restore-mission", false);
        set_menu_state("store-mission", false);
        set_menu_state("navconfig", false);
        set_menu_state("stop-replay", false);
        set_menu_state("mission-info", false);

        art_win = new ArtWin(conf.ah_inv_roll);

        var css = new Gtk.CssProvider ();
        var screen = Gdk.Screen.get_default();
        try
        {
            string cssfile = MWPUtils.find_conf_file("vcols.css");
            css.load_from_file(File.new_for_path(cssfile));
            Gtk.StyleContext.add_provider_for_screen(screen, css, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        } catch (Error e) {
            stderr.printf("context %s\n", e.message);
        }
        vcol = new VCol();

        odoview = new OdoView(builder,window,conf.stats_timeout);
        navstatus = new NavStatus(builder, vcol, conf.recip);
        radstatus = new RadioStatus(builder);
        telemstatus = new TelemetryStats(builder);
        fbox  = new FlightBox(builder,window);
        dbox = new DirnBox(builder, conf.horizontal_dbox);

        view = embed.get_view();
        view.set_reactive(true);

        view.notify["zoom-level"].connect(() => {
                var val = view.get_zoom_level();
                var zval = (int)zoomer.adjustment.value;
                if (val != zval)
                    zoomer.adjustment.value = (int)val;

                get_map_size();
            });

        zoomer.adjustment.value_changed.connect (() =>
            {
                int  zval = (int)zoomer.adjustment.value;
                var val = view.get_zoom_level();
                if (val != zval)
                    view.zoom_level = zval;
            });

        conf.settings_update.connect ((s) => {
                if (s == "display-dms" ||
                    s == "default-latitude" ||
                    s == "default-longitide")
                    anim_cb(true);

                if(s == "display-dms" ||
                    s == "display-distance" ||
                    s == "display-speed")
                {
                    fbox.update(item_visible(DOCKLETS.FBOX));
                }
            });

        view.set_keep_center_on_resize(true);

        prefs = new PrefsDialog(builder, window);

        add_source_combo(conf.defmap,msources);

        var ag = new Gtk.AccelGroup();

        ag.connect('?', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                pos_is_centre = !pos_is_centre;
                return true;
            });

        ag.connect('l', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                return clip_location(false);
            });

        ag.connect('l', Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK, 0, (a,o,k,m) => {
                return clip_location(true);
            });

        ag.connect('c', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                if(craft != null)
                {
                    markers.remove_rings(view);
                    craft.init_trail();
               }
                return true;
            });

        ag.connect('+', 0, 0, (a,o,k,m) => {
                var val = view.get_zoom_level();
                var mmax = view.get_max_zoom_level();
                if (val != mmax)
                    view.zoom_level = val+1;
                return true;
            });

        ag.connect('-', 0, 0, (a,o,k,m) => {
                var val = view.get_zoom_level();
                var mmin = view.get_min_zoom_level();
                if (val != mmin)
                    view.zoom_level = val-1;
                return true;
            });

        ag.connect('f', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                toggle_full_screen();
                return true;
            });

        ag.connect(Gdk.Key.F11, 0, 0, (a,o,k,m) => {
                toggle_full_screen();
                return true;
            });

        ag.connect('s', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                show_serial_stats();
                return true;
            });

        ag.connect('i', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                hard_display_reset(false);
                return true;
            });

        ag.connect('t', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                armtime = 0;
                duration = 0;
                return true;
            });

        ag.connect('c', Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK,
                   0, (a,o,k,m) => {
                       connect_serial();
                       return true;
                   });

        ag.connect('v', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                get_mission_pix();
                return true;
            });

        ag.connect('w', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                if(conf.auto_wp_edit == false)
                    wp_edit_button.active = !wp_edit;
                return true;
            });


        ag.connect('z', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                ls.clear_mission();
                wpmgr.wps = {};
                return true;
            });

        ag.connect('k', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                if(wpmgr.wp_flag != 0)
                {
                    wpmgr.wp_flag = WPDL.CANCEL;
                    remove_tid(ref upltid);
                    MWPCursor.set_normal_cursor(window);
                    reset_poller();
                    validatelab.set_text("⚠"); // u+26a0
                    mwp_warning_box("Upload cancelled", Gtk.MessageType.ERROR,10);
                }
                return true;
            });

        ag.connect('h', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                map_centre_on(conf.latitude,conf.longitude);
                return true;
            });

        ag.connect(' ', 0, 0, (a,o,k,m) => {
                if(replayer != Player.NONE)
                {
                    handle_replay_pause();
                    return true;
                }
                else return false;
            });

        ag.connect(Gdk.Key.Up, Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                key_recentre(Gdk.Key.Up);
                return true;
            });
        ag.connect(Gdk.Key.Down, Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                key_recentre(Gdk.Key.Down);
                return true;
            });
        ag.connect(Gdk.Key.Left, Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                key_recentre(Gdk.Key.Left);
                return true;
            });
        ag.connect(Gdk.Key.Right, Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                key_recentre(Gdk.Key.Right);
                return true;
            });

        window.add_accel_group(ag);

        ls = new ListBox();
        ls.create_view(this);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scroll.set_min_content_width(400);
        scroll.add (ls.view);

        var grid =  builder.get_object ("grid1") as Gtk.Grid;
        gpsinfo = new GPSInfo(grid, conf.deltaspeed);

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL,2);

        var pane = builder.get_object ("paned1") as Gtk.Paned;

        markers = new MWPMarkers(ls,view, conf.wp_spotlight);

/*
  Sample for range rings. Note that 1st is below second)
  So the following sets the markers *below* the paths, which is NOT wanted
  var pp  =  markers.path.get_parent();
  pp.set_child_below_sibling(markers.markers, markers.hpath);
  pp.set_child_below_sibling(markers.markers, markers.path);
*/
        poslabel = builder.get_object ("poslabel") as Gtk.Label;
        stslabel = builder.get_object ("missionlab") as Gtk.Label;
        statusbar = builder.get_object ("statusbar1") as Gtk.Statusbar;
        context_id = statusbar.get_context_id ("Starting");
        elapsedlab =  builder.get_object ("elapsedlab") as Gtk.Label;
        logb = builder.get_object ("logger_cb") as Gtk.CheckButton;
        logb.toggled.connect (() => {
                if (logb.active)
                {
                    Logger.start(conf.logsavepath);
                    if(armed != 0)
                    {
                        string devnam = null;
                        if(msp.available)
                            devnam = dev_entry.get_active_text();
                        Logger.fcinfo(last_file,vi,capability,profile, boxnames,
                                      vname, devnam);
                    }
                }
                else
                    Logger.stop();
            });

        autocon_cb = builder.get_object ("autocon_cb") as Gtk.CheckButton;

        audio_cb = builder.get_object ("audio_cb") as Gtk.CheckButton;
        audio_cb.sensitive = true; //(conf.speakint > 0);
        audio_cb.toggled.connect (() => {
                audio_on = audio_cb.active;
                if (audio_on)
                    start_audio();
                else
                    stop_audio();
            });
        var centreonb = builder.get_object ("checkbutton1") as Gtk.CheckButton;
        if(conf.use_legacy_centre_on)
            centreonb.set_label("Centre On");

        centreonb.active = centreon = conf.centreon;
        centreonb.toggled.connect (() => {
                centreon = centreonb.active;
            });


        var followb = builder.get_object ("checkbutton2") as Gtk.CheckButton;
        if(conf.autofollow)
        {
            follow = true;
            followb.active = true;
        }

        followb.toggled.connect (() => {
                follow = followb.active;
                if (follow == false && craft != null)
                {
                    craft.park();
                }
            });

        swd = new SwitchDialog(builder, window);

        about = builder.get_object ("aboutdialog1") as Gtk.AboutDialog;
        about.set_transient_for(window);
        StringBuilder sb = new StringBuilder(MwpVers.build);
        sb.append_c('\n');
        sb.append(MwpVers.id);
        if(is_wayland && use_wayland)
            sb.append("\non wayland\n");
        about.version = sb.str;

        about.copyright = "© 2014-%d Jonathan Hudson".printf(
            new DateTime.now_local().get_year());

        Gdk.Pixbuf pix = null;
        try  {
            pix = new Gdk.Pixbuf.from_file_at_size (icon, 200,200);
        } catch  {};
        about.logo = pix;

        msp = new MWSerial();
        msp.use_v2 = false;
        if(forward_device != null)
            fwddev = new MWSerial.forwarder();

        mq = new Queue<MQI?>();

        build_deventry();
        dev_entry.active = 0;

        devman.device_added.connect((s) => {
                if(s.contains(" ") || msp.available)
                    append_deventry(s);
                else
                    prepend_deventry(s);
            });
        devman.device_removed.connect((s) => {
                remove_deventry(s);
            });


        conbutton = builder.get_object ("button1") as Gtk.Button;

        var te = dev_entry.get_child() as Gtk.Entry;

        te.activate.connect(() => {
                if(!msp.available)
                    connect_serial();
            });

        verlab = builder.get_object ("verlab") as Gtk.Label;
        fmodelab = builder.get_object ("fmode") as Gtk.Label;
        validatelab = builder.get_object ("validated") as Gtk.Label;
        armed_spinner = builder.get_object ("armed_spinner") as Gtk.Spinner;
        typlab = builder.get_object ("typlab") as Gtk.Label;
        gpslab = builder.get_object ("gpslab") as Gtk.Label;
        conbutton.clicked.connect(() => { connect_serial(); });

        var zm = conf.zoom;
        clat= conf.latitude;
        clon = conf.longitude;

        kmls = new Array<KmlOverlay>();

        if(llstr != null)
        {
            string[] delims =  {","," "};
            foreach (var delim in delims)
            {
                var parts = llstr.split(delim);
                if(parts.length == 2)
                {
                    clat = InputParser.get_latitude(parts[0]);
                    clon = InputParser.get_longitude(parts[1]);
                    break;
                }
            }
        }
        else if (mission != null)
        {
            var ms = open_mission_file(mission);
            if(ms != null)
            {
                clat = ms.cy;
                clon = ms.cx;
                if(ms.zoom != 0)
                {
                    zm = ms.zoom;
                    instantiate_mission(ms);
                }
                else
                    Timeout.add(1000,() => {
                            instantiate_mission(ms);
                            return Source.REMOVE;
                        });
                last_file = mission;
                update_title_from_file(mission);
            }
        }

        if(kmlfile != null)
        {
            var ks = kmlfile.split(",");
            foreach(var kf in ks)
                try_load_overlay(kf);
        }

        map_centre_on(clat, clon);
        if (check_zoom_sanity(zm))
            view.zoom_level = zm;

        msp.force4 = force4;
        msp.serial_lost.connect(() => { serial_doom(conbutton); });

        msp.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
                handle_serial(cmd,raw,len,xflags,errs);
            });

        msp.sport_event.connect((id,val) => {
                process_sport_message ((SportDev.FrID)id, val);
            });

        if(serial != null)
        {
            dev_entry.prepend_text(serial);
            dev_entry.active = 0;
        }

        autocon_cb.toggled.connect(() => {
                autocon =  autocon_cb.active;
                autocount = 0;
            });

        if(conf.vlevels != null)
        {
            string [] parts;
            parts = conf.vlevels.split(";");
            var i = 0;
            foreach (unowned string str in parts)
            {
                var d = DStr.strtod(str,null);
                vcol.levels[i].cell = (float)d;
                i++;
            }
        }

        lastmsg = MQI(); //{cmd = MSP.Cmds.INVALID};

        start_poll_timer();
        lastp = new Timer();

        pane.pack1(embed,true, true);
        pane.pack2(box, true, true);

        Timeout.add_seconds(5, () => { return try_connect(); });
        if(set_fs)
            window.fullscreen();
        else if (no_max == false)
            window.maximize();
        else
        {
            Gdk.Rectangle rect = {0,0};
            if(get_primary_size(ref rect))
            {
                var rw = rect.width*80/100;
                var rh = rect.height*80/100;
                window.resize(rw,rh);
            }
        }

        window.size_allocate.connect((a) => {
                if(((a.width != window_w) || (a.height != window_h)))
                {
                    window_w  = a.width;
                    window_h = a.height;
                    var nppos = conf.window_p * (double)(pane.max_position - pane.min_position) /100.0;
                    pane.position = (int)Math.lround(nppos);
                    Idle.add(() => {
                            fbox.check_size();
                            return Source.REMOVE;
                        });
                    get_map_size();
                    map_warn_set_text();
                }
            });

        pane.button_press_event.connect((evt) => {
                fbox.allow_resize(true);
                return false;
            });

        pane.button_release_event.connect((evt) => {
                if (evt.button == 1)
                {
                    conf.window_p = 100.0* (double)pane.position /(double) (pane.max_position - pane.min_position);
                    conf.save_pane();
                }
                Timeout.add(500, () => {
                            fbox.allow_resize(false);
                        return Source.REMOVE;
                    });
                return false;
            });

        window.show_all();

        if((wp_edit = conf.auto_wp_edit) == true)
            wp_edit_button.hide();
        else
            wp_edit_button.show();

        if(wdw_state == false)
            fsmenu_button.hide();

        arm_warn.hide();

        anim_cb(true);

        var scale = new Champlain.Scale();
        scale.connect_view(view);
        view.add_child(scale);
        Clutter.LayoutManager lm = view.get_layout_manager();
        lm.child_set(view,scale,"x-align", Clutter.ActorAlign.START);
        lm.child_set(view,scale,"y-align", Clutter.ActorAlign.END);
        map_init_warning(lm);

        var dock = new Dock ();
        dock.margin_start = 4;
        var dockbar = new DockBar (dock);
        dockbar.set_style (DockBarStyle.ICONS);
        lman = new LayMan(dock, confdir,layfile,DOCKLETS.NUMBER);

        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);

        dockitem = new DockItem[DOCKLETS.NUMBER];

        dockitem[DOCKLETS.GPS]= new DockItem.with_stock ("GPS",
                                                         "GPS Info", "gtk-refresh",
                                                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.NAVSTATUS]= new DockItem.with_stock ("Status",
                         "NAV Status", "gtk-info",
                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.ARTHOR]= new DockItem.with_stock ("Horizons",
                         "Artificial Horizon", "gtk-justify-fill",
                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.VOLTAGE]= new DockItem.with_stock ("Volts",
                         "Battery Monitor", "gtk-dialog-warning",
                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.RADIO]= new DockItem.with_stock ("Radio",
                         "Radio Status", "gtk-network",
                         DockItemBehavior.NORMAL );
        dock.add_item (dockitem[DOCKLETS.RADIO], DockPlacement.BOTTOM);

        dockitem[DOCKLETS.TELEMETRY]= new DockItem.with_stock ("Telemetry",
                         "Telemetry", "gtk-disconnect",
                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.FBOX]= new DockItem.with_stock ("FlightView",
                         "FlightView", "gtk-find",
                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.DBOX]= new DockItem.with_stock ("DirectionView",
                         "DirectionView", "gtk-fullscreen",
                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.MISSION]= new DockItem.with_stock ("Mission",
                         "Mission Tote", "gtk-properties",
                         DockItemBehavior.NORMAL);

        dockitem[DOCKLETS.VOLTAGE].add (navstatus.voltbox);
        dockitem[DOCKLETS.MISSION].add (scroll);
        dockitem[DOCKLETS.GPS].add (grid);
        dockitem[DOCKLETS.NAVSTATUS].add (navstatus.grid);
        dockitem[DOCKLETS.RADIO].add (radstatus.box);
        dockitem[DOCKLETS.TELEMETRY].add (telemstatus.grid);
        dockitem[DOCKLETS.FBOX].add (fbox.vbox);
        dockitem[DOCKLETS.DBOX].add (dbox.dbox);
        dockitem[DOCKLETS.ARTHOR].add (art_win.box);

        dock.add_item (dockitem[DOCKLETS.ARTHOR], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.GPS], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.NAVSTATUS], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.VOLTAGE], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.TELEMETRY], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.RADIO], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.FBOX], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.DBOX], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.MISSION], DockPlacement.BOTTOM);
        box.show_all();

        if(!lman.load_init())
        {
            dockitem[DOCKLETS.ARTHOR].iconify_item ();
            dockitem[DOCKLETS.GPS].iconify_item ();
            dockitem[DOCKLETS.NAVSTATUS].iconify_item ();
            dockitem[DOCKLETS.VOLTAGE].iconify_item ();
            dockitem[DOCKLETS.RADIO].iconify_item ();
            dockitem[DOCKLETS.TELEMETRY].iconify_item ();
            dockitem[DOCKLETS.FBOX].iconify_item ();
            dockitem[DOCKLETS.DBOX].iconify_item ();
            lman.save_config();
        }

        mwpdh = new MwpDockHelper(dockitem[DOCKLETS.MISSION], dock,
                          "Mission Editor", conf.tote_floating);
        mwpdh.transient(window);

        mwpdh.menu_key.connect(() => {
                ls.show_tote_popup(null);
            });

        fbox.update(true);

        if(conf.mavph != null)
            parse_rc_mav(conf.mavph, Craft.Special.PH);

        if(conf.mavrth != null)
            parse_rc_mav(conf.mavrth, Craft.Special.RTH);

        Gtk.drag_dest_set (window, Gtk.DestDefaults.ALL,
                           targets, Gdk.DragAction.COPY);

       window.drag_data_received.connect(
            (ctx, x, y, data, info, time) => {
                string mf = null; // mission
                string sf = null; // replay (bbox / mwp)
                string kf = null; // overlay
                bool bbox = false;
                uint8 buf[1024];
                foreach(var uri in data.get_uris ())
                {
                    try {
                        var f = Filename.from_uri(uri);
                        var fs = FileStream.open (f, "r");
                        var nr =  fs.read (buf);
                        if (nr > 0) {
                            if(buf[0] == '<')
                            {
                                buf[nr-1] = 0;
                                string s = (string)buf;
                                if(s.contains("<MISSION>"))
                                    mf = f;
                                else if(s.contains("<kml "))
                                    kf = f;
                            }
                            else if (f.has_suffix(".kmz") && x_kmz &&
                                     buf[0] == 'P' &&
                                     buf[1] == 'K' &&
                                     buf[2] == 3 && buf[3] == 4)
                            {
                                kf = f;
                            }
                            else if(buf[0] == 'H' && buf[1] == ' ')
                            {
                                sf = f;
                                bbox = true;
                            }
                            else if(buf[0] == '{')
                            {
                                if(buf[1] == '"')
                                    sf = f;
                                else if (buf[1] == '\n')
                                    mf = f;
                            }
                        }
                    } catch (Error e) {
                        MWPLog.message("dnd: %s\n", e.message);
                    }
                }
                Gtk.drag_finish (ctx, true, false, time);
                if(mf != null)
                    load_file(mf);
                if(kf != null)
                    try_load_overlay(kf);

                if(sf != null)
                {
                    if(bbox)
                        replay_bbox(true, sf);
                    else
                        run_replay(sf, true, Player.MWP);
                }
            });

       setup_buttons();
       set_dock_menu_status();
       dock.layout_changed.connect(() => {
               set_dock_menu_status();
           });

       get_map_size();

       acquire_bus();

       if(rfile != null)
       {
           usemag = force_mag;
           Timeout.add(600, () => {
                   run_replay(Posix.realpath(rfile), true, Player.MWP);
                   return false;
               });
       }
       else if(bfile != null)
       {
           usemag = force_mag;
           Timeout.add(600, () => {
                   replay_bbox(true, Posix.realpath(bfile));
                   return false;
               });
       }

        if(sport_device != null)
            append_deventry("*SMARTPORT*");

       if(mkcon)
        {
            connect_serial();
        }

        if(autocon)
        {
            autocon_cb.active=true;
            mkcon = true;
        }

        if(conf.mag_sanity != null)
        {
            var parts=conf.mag_sanity.split(",");
            if (parts.length == 2)
            {
                magdiff=int.parse(parts[0]);
                magtime=int.parse(parts[1]);
                MWPLog.message("Enabled mag anonaly checking %d⁰, %ds\n", magdiff,magtime);
                magcheck = true;
            }
        }
    }

    private void try_load_overlay(string kf)
    {
        var kml = new KmlOverlay(view);
        if(kml.load_overlay(kf))
        {
            kmls.append_val (kml);
            set_menu_state("kml-remove", true);
        }
    }

    private bool is_kml_loaded(string name)
    {
        var found = false;
        for (int i = 0; i < kmls.length ; i++)
        {
            if(name == kmls.index(i).get_filename())
            {
                found = true;
                break;
            }
        }
        return found;
    }

    private void kml_load_dialog()
    {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select Overlay(s)", null, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);
        chooser.select_multiple = true;

        chooser.set_transient_for(window);
        Gtk.FileFilter filter = new Gtk.FileFilter ();
        StringBuilder sb = new StringBuilder("KML");
        filter.add_pattern ("*.kml");
        if(x_kmz)
        {
            filter.add_pattern ("*.kmz");
            sb.append(" & KMZ");
        }
        sb.append(" files");
        filter.set_filter_name (sb.str);
        chooser.add_filter (filter);
        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);

        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT)
                {
                    var fns = chooser.get_filenames ();
                    chooser.close ();
                    foreach(var fn in fns)
                    {
                        if(is_kml_loaded(fn) == false)
                            try_load_overlay(fn);
                    }
                }
                else
                    chooser.close ();
            });
        chooser.show_all();
    }

    private void kml_remove_dialog()
    {
        var dialog = new Dialog.with_buttons ("Remove KML", null,
                                              DialogFlags.MODAL |
                                              DialogFlags.DESTROY_WITH_PARENT,
                                              "Cancel", ResponseType.CANCEL,
                                              "OK", ResponseType.OK);

        Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        var content = dialog.get_content_area ();
        content.pack_start (box, false, false, 0);

        CheckButton[] btns = {};

        for (int i = 0; i < kmls.length ; i++)
        {
            var s = kmls.index(i).get_filename();
            var button = new Gtk.CheckButton.with_label(s);
            btns += button;
            box.pack_start (button, false, false, 0);
        }

        box.show_all ();
        var response = dialog.run ();
        if (response == ResponseType.OK)
        {
            var i = btns.length;
            foreach (var b in btns)
            {
                i--;
                if(b.get_active())
                {
                    kmls.index(i).remove_overlay();
                    kmls.remove_index(i);
                }
            }
        }
        set_menu_state("kml-remove", (kmls.length != 0));
        dialog.destroy ();
    }

    private void remove_all_kml()
    {
        for (int i = 0; i < kmls.length ; i++)
        {
            kmls.index(i).remove_overlay();
        }
        kmls.remove_range(0,kmls.length);
        set_menu_state("kml-remove", false);
    }

    private uint8 sport_parse_lat_lon(uint val, out int32 value)
    {
        uint8 imode = (uint8)(val >> 31);
        value = (int)(val & 0x3fffffff);
        if ((val & (1 << 30))!= 0)
            value = -value;
        value = (50*value) / 3; // min/10000 => deg/10000000
        return imode;
    }


    private void process_sport_message (SportDev.FrID id, uint32 val)
    {
        double r;
        if(Logger.is_logging)
            Logger.log_time();

        lastrx = lastok = nticks;
        if(rxerr)
        {
            set_error_status(null);
            rxerr=false;
        }

        switch(id)
        {
            case SportDev.FrID.VFAS_ID:
                if (val /100  < 80)
                {
                    spi.volts = val / 100.0;
                    sflags |=  NavStatus.SPK.Volts;
                }
                break;
            case SportDev.FrID.GPS_LONG_LATI_ID:
                int32 ipos;
                uint8 lorl = sport_parse_lat_lon (val, out ipos);
                if (lorl == 0)
                    spi.lat = ipos;
                else
                {
                    spi.lon = ipos;
                    init_craft_icon();
                    MSP_ALTITUDE al = MSP_ALTITUDE();
                    al.estalt = spi.alt;
                    al.vario = spi.vario;
                    navstatus.set_altitude(al, item_visible(DOCKLETS.NAVSTATUS));
                    double ddm;
                    gpsinfo.update_sport(spi, conf.dms, item_visible(DOCKLETS.GPS), out ddm);

                    if(spi.fix > 0)
                    {
                        sat_coverage();
                        if(armed != 0)
                        {
                            if(have_home)
                            {
                                if(_nsats >= msats)
                                {
                                    if(pos_valid(GPSInfo.lat, GPSInfo.lon))
                                    {
                                        double dist,cse;
                                        Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                                                    home_pos.lat, home_pos.lon,
                                                    out dist, out cse);
                                        if(dist < 256)
                                        {
                                            var cg = MSP_COMP_GPS();
                                            cg.range = (uint16)Math.lround(dist*1852);
                                            cg.direction = (int16)Math.lround(cse);
                                            navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
                                            update_odo(spi.spd, ddm);
                                            spi.range =  cg.range;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                if(no_ofix == 10)
                                {
                                    MWPLog.message("No home position yet\n");
                                }
                            }
                        }

                        if(craft != null && spi.fix > 0 && spi.sats >= msats)
                        {
                            update_pos_info();
                        }

                        if(want_special != 0)
                            process_pos_states(GPSInfo.lat, GPSInfo.lon, spi.alt/100.0, "Sport");
                    }
                    fbox.update(item_visible(DOCKLETS.FBOX));
                    dbox.update(item_visible(DOCKLETS.DBOX));
                }
                break;
            case SportDev.FrID.GPS_ALT_ID:
                r =((int)val) / 100.0;
                spi.galt = r;
                break;
            case SportDev.FrID.GPS_SPEED_ID:
                r = ((val/1000.0)*0.51444444);
                spi.spd = r;
                break;
            case SportDev.FrID.GPS_COURS_ID:
                r = val / 100.0;
                spi.cse = r;
                navstatus.sport_hdr(r);
                break;
            case SportDev.FrID.ADC2_ID: // AKA HDOP
                rhdop = (uint16)((val &0xff)*10);
                spi.rhdop = rhdop;
                spi.flags |= 1;
                break;
            case SportDev.FrID.ALT_ID:
                r = (int)val / 100.0;
                spi.alt = (int)val;
                sflags |=  NavStatus.SPK.ELEV;
                break;
            case SportDev.FrID.T1_ID: // flight modes
                uint ival = val;
                uint32 arm_flags = 0;
                uint64 mwflags = 0;
                uint8 ltmflags = 0;
                bool failsafe = false;

                for(var j = 0; j < 5; j++)
                {
                    uint mode = ival % 10;
                    switch(j)
                    {
                        case 0: // 1s
                            if((mode & 1) == 0)
                                arm_flags |=  ARMFLAGS.ARMING_DISABLED_OTHER;
                            if ((mode & 4) == 4) // armed
                            {
                                mwflags = arm_mask;
                                armed = 1;
                                dac = 0;
                            }
                            else
                            {
                                dac++;
                                if(dac == 1 && armed != 0)
                                {
                                    MWPLog.message("Assumed disarm from SPORT %ds\n", duration);
                                    mwflags = 0;
                                    armed = 0;
                                    init_have_home();
                                }
                            }
                            break;
                        case 1: // 10s
                            if(mode == 0)
                                ltmflags = 4;
                            if (mode == 1)
                                ltmflags = 2;
                            else if (mode == 2)
                                ltmflags = 3;
                            else if(mode == 4)
                                ltmflags = 0;
                            break;
                        case 2: // 100s
//                            if((mode & 1) == 1) // "Heading "
                            if((mode & 2) == 2)
                                ltmflags = 8;
                            if((mode & 4) == 4)
                                ltmflags = 9;
                            break;
                        case 3: // 1000s
                            if(mode == 1)
                                ltmflags = 13;
                            if(mode == 2)
                                ltmflags = 10;
//                            if(mode == 4) ltmflags = 11;
                            if(mode == 8)
                                ltmflags = 18;
                            break;
                        case 4: // 10000s
                                // if(mode == 2) emode = "AUTOTUNE";
                            failsafe = (mode == 4);
                            if(xfailsafe != failsafe)
                            {
                                if(failsafe)
                                {
                                    arm_flags |=  ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
                                    MWPLog.message("Failsafe asserted %ds\n", duration);
                                    map_show_warning("FAILSAFE");
                                }
                                else
                                {
                                    MWPLog.message("Failsafe cleared %ds\n", duration);
                                    map_hide_warning();
                                }
                                xfailsafe = failsafe;
                            }
                            break;
                    }
                    ival = ival / 10;
                }
                if(arm_flags != xarm_flags)
                {
                    xarm_flags = arm_flags;
                   if((arm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0)
                    {
                        arm_warn.show();
                    }
                    else
                    {
                        arm_warn.hide();
                    }
                }

                if(ltmflags == 2)
                    mwflags |= angle_mask;
                if(ltmflags == 3)
                    mwflags |= horz_mask;
                if(ltmflags == 3)
                    mwflags |= arm_mask;
                if(ltmflags == 9)
                    mwflags |= ph_mask;
                if(ltmflags == 10)
                    mwflags |= wp_mask;
                if(ltmflags == 13 || ltmflags == 15)
                    mwflags |= rth_mask;
                else
                    mwflags = xbits; // don't know better

                armed_processing(mwflags,"Sport");
                var xws = want_special;
                if(ltmflags != last_ltmf)
                {
                    last_ltmf = ltmflags;
                    if(ltmflags == 9)
                        want_special |= POSMODE.PH;
                    else if(ltmflags == 10)
                    {
                        want_special |= POSMODE.WP;
                        if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
                            NavStatus.nm_pts = last_wp_pts;
                    }
                    else if(ltmflags == 13)
                        want_special |= POSMODE.RTH;
                    else if(ltmflags == 8)
                        want_special |= POSMODE.ALTH;
                    else if(ltmflags == 18)
                        want_special |= POSMODE.CRUISE;
                    else if(ltmflags != 15)
                    {
                        if(craft != null)
                            craft.set_normal();
                    }
                    var lmstr = MSP.ltm_mode(ltmflags);
                    MWPLog.message("New SPort/LTM Mode %s (%d) %d %ds %f %f %x %x\n",
                                   lmstr, ltmflags, armed, duration, xlat, xlon,
                                   xws, want_special);
                    fmodelab.set_label(lmstr);
                }
                if(want_special != 0 /* && have_home*/)
                    process_pos_states(xlat,xlon, 0, "SPort status");

                LTM_SFRAME sf = LTM_SFRAME ();
                sf.vbat = (uint16)(spi.volts*1000);
                sf.flags = ((failsafe) ? 2 : 0) | (armed & 1) | (ltmflags << 2);
                sf.vcurr = (conf.smartport_fuel == 2) ? (uint16)curr.mah : 0;
                sf.rssi = (uint8)(spi.rssi * 255/ 1023);
                sf.airspeed = 0;
                navstatus.update_ltm_s(sf, item_visible(DOCKLETS.NAVSTATUS),true);
                break;

            case SportDev.FrID.T2_ID: // GPS info
                uint8 ifix = 0;
                _nsats = (uint8)(val % 100);
                uint16 hdp;
                hdp = (uint16)(val % 1000)/100;
                if (spi.flags == 0) // prefer FR_ID_ADC2_ID
                    spi.rhdop = rhdop = 550 - (hdp * 50);

                uint8 gfix = (uint8)(val /1000);
                if ((gfix & 1) == 1)
                    ifix = 3;
                if ((gfix & 2) == 2)
                {
                    if(have_home == false && armed != 0)
                    {
                        if(home_changed(GPSInfo.lat, GPSInfo.lon))
                        {
                            if(spi.fix == 0)
                            {
                                no_ofix++;
                            }
                            else
                            {
                                navstatus.cg_on();
                                sflags |=  NavStatus.SPK.GPS;
                                want_special |= POSMODE.HOME;
                                process_pos_states(GPSInfo.lat, GPSInfo.lon, 0.0, "SPort");
                            }
                        }
                    }
                }
                if ((gfix & 4) == 4)
                {
                    if (spi.range < 500)
                    {
                        MWPLog.message("SPORT: %s set home: changed home position %f %f\n",
                                       id.to_string(), GPSInfo.lat, GPSInfo.lon);
                        home_changed(GPSInfo.lat, GPSInfo.lon);
                        want_special |= POSMODE.HOME;
                        process_pos_states(GPSInfo.lat, GPSInfo.lon, 0.0, "SPort");
                    }
                    else
                    {
                        MWPLog.message("SPORT: %s Ignoring (bogus?) set home, range > 500m: requested home position %f %f\n", id.to_string(), GPSInfo.lat, GPSInfo.lon);
                    }
                }

                if((_nsats == 0 && nsats != 0) || (nsats == 0 && _nsats != 0))
                {
                    nsats = _nsats;
                    navstatus.sats(_nsats, true);
                }
                spi.sats = _nsats;
                spi.fix = ifix;
                flash_gps();
                last_gps = nticks;
                break;
            case SportDev.FrID.RSSI_ID:
                    /****
                    // http://ceptimus.co.uk/?p=271
                    // states main (Rx) link quality 100+ is full signal
                    // 40 is no signal --- iNav uses 0 - 1023
                    //
                uint rssi;
                uint issr;
                rssi = (val & 0xff);
                if (rssi > 100)
                    rssi = 100;
                if (rssi < 40)
                    rssi = 40;
                issr = (rssi - 40)*1023/60;
                    *******/
                spi.rssi = (uint16)((val&0xff)*1023/100);
                MSP_ANALOG an = MSP_ANALOG();
                an.rssi = spi.rssi;
                an.vbat = (uint8)(spi.volts * 10);

                an.powermetersum = (conf.smartport_fuel == 2 )? (uint16)curr.mah :0;
                an.amps = curr.centiA;
                process_msp_analog(an);
                break;
            case SportDev.FrID.PITCH:
            case SportDev.FrID.ROLL:
                if (id == SportDev.FrID.ROLL)
                    spi.roll = (int16)val;
                else
                    spi.pitch = (int16)val;

                LTM_AFRAME af = LTM_AFRAME();
                af.pitch = spi.pitch;
                af.roll = spi.roll;
                af.heading = mhead = (int16) spi.cse;
                navstatus.update_ltm_a(af, true);
                art_win.update(af.roll*10, af.pitch*10, item_visible(DOCKLETS.ARTHOR));
                if(Logger.is_logging)
                    Logger.attitude((double)spi.pitch, (double)spi.roll, (int)mhead);
                break;

            case SportDev.FrID.HOME_DIST:
                int diff = (int)(spi.range - val);
                if(spi.range > 100 && (diff * 100 / spi.range) > 9)
                    MWPLog.message("%s %um (mwp: %u, diff: %d)\n", id.to_string(), val, spi.range, diff);
                break;

            case SportDev.FrID.CURR_ID:
                if((val / 10) < 999)
                {
                    curr.ampsok = true;
                    curr.centiA =  (uint16)(val * 10);
                    if (curr.centiA > odo.amps)
                        odo.amps = curr.centiA;
                    navstatus.current(curr, conf.smartport_fuel);
                }
                break;
            case SportDev.FrID.ACCX_ID:
                spi.ax = ((int)val) / 100.0;
                break;
            case SportDev.FrID.ACCY_ID:
                spi.ay = ((int)val) / 100.0;
                break;
            case SportDev.FrID.ACCZ_ID:
                spi.az = ((int)val) / 100.0;
                spi.pitch = -(int16)(180.0 * Math.atan2 (spi.ax, Math.sqrt(spi.ay*spi.ay + spi.az*spi.az))/Math.PI);
                spi.roll  = (int16)(180.0 * Math.atan2 (spi.ay, Math.sqrt(spi.ax*spi.ax + spi.az*spi.az))/Math.PI);
                art_win.update(spi.roll*10, spi.pitch*10, item_visible(DOCKLETS.ARTHOR));
                if(Logger.is_logging)
                    Logger.attitude((double)spi.pitch, (double)spi.roll, (int16) spi.cse);
                break;

            case SportDev.FrID.VARIO_ID:
                spi.vario = (int16)((int) val / 10);
                break;

            case SportDev.FrID.FUEL_ID:
                switch (conf.smartport_fuel)
                {
                    case 0:
                        curr.mah = 0;
                        break;
                    case 1:
                    case 2:
                        curr.mah = (val > 0xffff) ? 0xffff : (uint16)val;
                        break;
                    case 3:
                    default:
                        curr.mah = val;
                        break;
                }
                break;

            default:
                break;
        }
    }

    private bool clip_location(bool fmt)
    {
        int mx,my;
        Gdk.Display display = Gdk.Display.get_default ();
        Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
#if OLDGTK||LSRVAL
        embed.get_pointer(out mx, out my);
#else
        var seat = display.get_default_seat();
        var ptr = seat.get_pointer();
        embed.get_window().get_device_position(ptr, out mx, out my, null);
#endif
        var lon = view.x_to_longitude (mx);
        var lat = view.y_to_latitude (my);
        string pos;
        if(fmt)
            pos = PosFormat.pos(lat,lon,conf.dms);
        else
            pos = "%f %f".printf(lat,lon);
        clipboard.set_text (pos, -1);
        return true;
    }

    private void hard_display_reset(bool cm = false)
    {
        if(cm)
        {
            ls.clear_mission();
            wpmgr.wps = {};
        }
        map_hide_warning();
        map_hide_wp();
        init_sstats();
        armed = 0;
        rhdop = 10000;
        init_have_home();
        armed_spinner.stop();
        armed_spinner.hide();
        if (conf.audioarmed == true)
            audio_cb.active = false;
        if(conf.logarmed == true)
            logb.active=false;
        gpsinfo.annul();
        navstatus.annul();
        dbox.annul();
        fbox.annul();
        art_win.update(0, 0, item_visible(DOCKLETS.ARTHOR));
        set_bat_stat(0);
        duration = -1;
        if(craft != null)
        {
            craft.remove_marker();
            markers.remove_rings(view);
        }
        set_error_status(null);
        xsensor = 0;
        clear_sensor_array();
        remove_all_kml();
    }

    private void key_recentre(uint key)
    {
        var bb = view.get_bounding_box();
        var x = view.get_center_longitude();
        var y = view.get_center_latitude();
        switch (key)
        {
            case Gdk.Key.Up:
                y = (bb.top + 7*y)/8.0;
                break;
            case Gdk.Key.Down:
                y = (bb.bottom + 7*y)/8.0;
                break;
            case Gdk.Key.Left:
                x = (bb.left + 7*x)/8.0;
                break;
            case Gdk.Key.Right:
                x = (bb.right + 7*x)/8.0;
                break;
        }
        view.center_on(y,x);
    }

    private void acquire_bus()
    {
        Bus.own_name (BusType.SESSION, "org.mwptools.mwp", BusNameOwnerFlags.NONE,
                      on_bus_aquired,
                      () => {},
                      () => {
                          stderr.printf ("Could not aquire name\n");
                      });
    }

    private void on_bus_aquired (DBusConnection conn)
    {
        try {
            conn.register_object ("/org/mwptools/mwp",
                                  (mss = new MwpServer ()));
        } catch (IOError e) {
            stderr.printf ("Could not register service\n");
        }

        mss.__set_mission.connect((s) => {
                Mission ms;
                unichar c = s.get_char(0);

                if(c == '<')
                    ms = XmlIO.read_xml_string(s);
                else
                    ms = JsonIO.from_json(s);

                if(ms != null)
                    instantiate_mission(ms);
                return (ms != null) ? ms.npoints : 0;
            });

        mss.__load_mission.connect((s) => {
                Mission ms;
                ms = open_mission_file(s);
                if(ms != null)
                    instantiate_mission(ms);
                return (ms != null) ? ms.npoints : 0;
            });

        mss.__clear_mission.connect(() => {
                ls.clear_mission();
                NavStatus.have_rth = false;
                NavStatus.nm_pts = 0;
            });

        mss.__get_devices.connect(() => {
                int idx;
                mss.device_names = list_devices();
                idx =(msp.available) ? dev_entry.active : -1;
                return idx;
            });

        mss.__upload_mission.connect((e) => {
                var flag = WPDL.CALLBACK;
                flag |= ((e) ? WPDL.SAVE_EEPROM : WPDL.VALIDATE);
                upload_mission(flag);
            });

        mss.__connect_device.connect((s) => {
                int n = append_deventry(s);
                dev_entry.active = n;
                connect_serial();
                return msp.available;
            });

    }

    private void upload_callback(int pts)
    {
        wpmgr.wp_flag &= ~WPDL.CALLBACK;
        mss.nwpts = pts;
            // must use Idle.add as we may not otherwise hit the mainloop
        Idle.add(() => { mss.callback(); return false; });
    }

    private void get_map_size()
    {
        var bb = view.get_bounding_box();
        double dist,cse;
        double apos;

        apos = (bb.top+bb.bottom)/2;
        Geo.csedist(apos, bb.left, apos, bb.right, out dist, out cse);
        mapsize.width = dist *= 1852.0;

        apos = (bb.left+bb.right)/2;
        Geo.csedist(bb.top, apos, bb.bottom, apos, out dist, out cse);
        mapsize.height = dist *= 1852.0;
    }

    private bool get_primary_size(ref Gdk.Rectangle rect)
    {
        bool ret = true;

#if OLDGTK||LSRVAL
        var screen = Gdk.Screen.get_default();
        var mon = screen.get_monitor_at_point(1,1);
        screen.get_monitor_geometry(mon, out rect);
#else
        Gdk.Display dp = Gdk.Display.get_default();
        var mon = dp.get_monitor(0);
        if(mon != null)
            rect = mon.get_geometry();
        else
            ret = false;
#endif
        return ret;
    }

    public void build_deventry()
    {
        dev_entry.remove_all ();
        foreach (var s in devman.get_serial_devices())
            prepend_deventry(s);

        foreach(string a in conf.devices)
        {
            dev_entry.append_text(a);
        }

        foreach (var s in devman.get_bt_serial_devices())
            append_deventry(s);
    }

    private string?[] list_devices()
    {
        string[] devs={};
        var m = dev_entry.get_model();
        Gtk.TreeIter iter;
        bool next;

        for(next = m.get_iter_first(out iter); next; next = m.iter_next(ref iter))
        {
            GLib.Value cell;
            m.get_value (iter, 0, out cell);
            devs += (string)cell;
        }
        return devs;
    }

    private int find_deventry(string s)
    {
        var m = dev_entry.get_model();
        Gtk.TreeIter iter;
        int i,n = -1;
        bool next;

        for(i = 0, next = m.get_iter_first(out iter);
            next; next = m.iter_next(ref iter), i++)
        {
            GLib.Value cell;
            m.get_value (iter, 0, out cell);
            if((string)cell == s)
            {
                n = i;
                break;
            }
        }
        return n;
    }

    private int append_deventry(string s)
    {
        var n = find_deventry(s);
        if (n == -1)
        {
            dev_entry.append_text(s);
            n = 0;
        }
        if(dev_entry.active == -1)
            dev_entry.active = 0;
        return n;
    }

    private void prepend_deventry(string s)
    {
        var n = find_deventry(s);
        if (n == -1)
        {
            dev_entry.prepend_text(s);
            dev_entry.active = 0;
        }
        else
            dev_entry.active = n;
    }

    private void remove_deventry(string s)
    {
        foreach(string a in conf.devices)
            if (a == s)
                return;

        var n = find_deventry(s);
        if (n != -1)
        {
            dev_entry.remove(n);
            dev_entry.active = 0;
        }
    }

    private bool map_moved()
    {
        bool ret = false;
        var x = view.get_center_longitude();
        var y = view.get_center_latitude();

        if (lx !=  x || ly != y)
        {
            ly=y;
            lx=x;
            ret = true;
        }
        return ret;
    }

    private void setup_buttons()
    {
        embed.button_release_event.connect((evt) => {
                if(evt.button == 3)
                    ls.pop_marker_menu(evt);
                return false;
            });

        view.button_release_event.connect((evt) => {
                bool ret = false;
                if (evt.button == 1 && wp_edit && !map_moved())
                {
                    insert_new_wp(evt.x, evt.y);
                    ret = true;
                }
                else
                {
                    anim_cb(false);
                }
                return ret;
            });

        view.motion_event.connect ((evt) => {
                if (!pos_is_centre)
                {
                    var lon = view.x_to_longitude (evt.x);
                    var lat = view.y_to_latitude (evt.y);
                    poslabel.label = PosFormat.pos(lat,lon,conf.dms);
                }
                return false;
            });

    }

    private void insert_new_wp(float x, float y)
    {
        var lon = view.x_to_longitude (x);
        var lat = view.y_to_latitude (y);
        ls.insert_item(MSP.Action.WAYPOINT, lat,lon);
        ls.calc_mission();
    }

    private void parse_rc_mav(string s, Craft.Special ptype)
    {
        var parts = s.split(":");
        if(parts.length == 3)
        {
            mavposdef += MavPOSDef() { minval=(uint16)int.parse(parts[1]),
                    maxval=(uint16)int.parse(parts[2]),
                    ptype = ptype,
                    chan = (uint8)int.parse(parts[0]), set =0};
        }
    }

    private void toggle_full_screen()
    {
        if(wdw_state == true)
        {
            window.unfullscreen();
        }
        else
        {
            window.fullscreen();
        }
        mwpdh.transient(window, !wdw_state);
    }

    private bool try_connect()
    {
        if(autocon)
        {
            if(!msp.available)
                connect_serial();
            Timeout.add_seconds(5, () => { return try_connect(); });
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    }

    private void set_error_status(string? e)
    {
        if(e != null)
        {
            MWPLog.message("message => %s\n", e);
            statusbar.push(context_id, e);
            bleet_sans_merci(Alert.GENERAL);
        }
        else
        {
            statusbar.push(context_id, "");
        }
    }

    private void msg_poller()
    {
        if(serstate == SERSTATE.POLLER)
        {
            lastp.start();
            send_poll();
        }
    }

    private bool pos_valid(double lat, double lon)
    {
        bool vpos;

        if(have_home)
        {
            if( (Math.fabs(lat - xlat) < 0.25) &&
                (Math.fabs(lon - xlon) < 0.25))
            {
                vpos = true;
                xlat = lat;
                xlon = lon;
            }
            else
            {
                vpos = false;
                if(xlat != 0.0 && xlon != 0.0)
                    MWPLog.message("Ignore bogus %f %f (%f %f)\n",
                                   lat, lon, xlat, xlon);
            }
        }
        else
            vpos = true;
        return vpos;
    }


    private void resend_last()
    {
        if(msp.available)
        {
            if(lastmsg.cmd != MSP.Cmds.INVALID)
            {
//                MWPLog.message("resend %s\n", lastmsg.cmd.to_string());
                msp.send_command((uint16)lastmsg.cmd, lastmsg.data, lastmsg.len);
            }
            else
                run_queue();
        }
    }

    private void  run_queue()
    {
        if(msp.available && !mq.is_empty())
        {
            lastmsg = mq.pop_head();
//            MWPLog.message("send %s\n", lastmsg.cmd.to_string());
            msp.send_command((uint16)lastmsg.cmd, lastmsg.data, lastmsg.len);
        }
    }

    private void start_poll_timer()
    {
        var lmin = 0;

        Timeout.add(TIMINTVL, () => {
                nticks++;

/**********************
                if((nticks % 10) == 0)
                {
                    MWPLog.message("#### %s %s %s %s\n",
                                   msp.available.to_string(),
                                   nticks.to_string(),
                                   lastrx.to_string(),
                                   serstate.to_string());
                }
****************/
                if(msp.available)
                {
                    if(serstate != SERSTATE.NONE)
                    {
                        var tlimit = conf.polltimeout / TIMINTVL;
                        if((serstate == SERSTATE.POLLER ||
                            serstate == SERSTATE.TELEM) &&
                           (nticks - lastrx) > NODATAINTVL)
                        {
                            if(rxerr == false)
                            {
                                set_error_status("No data for 5s");
                                rxerr=true;
                            }
                        }

                        if(serstate != SERSTATE.TELEM)
                        {
// Probably takes a minute to change the LIPO
                            if(serstate == SERSTATE.POLLER &&
                               nticks - lastrx > RESTARTINTVL)
                            {
                                serstate = SERSTATE.NONE;
                                MWPLog.message("Restart poll loop\n");
                                init_state();
                                init_sstats();
                                init_have_home();
                                serstate = SERSTATE.NORMAL;
                                queue_cmd(MSP.Cmds.IDENT,null,0);
                                run_queue();
                            }
                            else if ((nticks - lastok) > tlimit )
                            {
                                telstats.toc++;
                                string res;
                                if(lastmsg.cmd != MSP.Cmds.INVALID)
                                {
                                    res = lastmsg.cmd.to_string();
                                }
                                else
                                    res = "%d".printf(tcycle);
                                if(nopoll == false)
                                    MWPLog.message("MSP Timeout (%s)\n", res);
                                lastok = nticks;
                                tcycle = 0;
                                resend_last();
                            }
                        }
                        else
                        {
                            if(armed != 0 && msp.available &&
                               gpsintvl != 0 && last_gps != 0)
                            {
                                if (nticks - last_gps > gpsintvl)
                                {
                                    if(replayer == Player.NONE)
                                        bleet_sans_merci(Alert.SAT);
                                    if(replay_paused == false)
                                        MWPLog.message("GPS stalled\n");
                                    gpslab.label = "<span foreground = \"red\">⬤</span>";
                                    last_gps = nticks;
                                }
                            }

                            if(serstate == SERSTATE.TELEM && nopoll == false &&
                               last_tm > 0 &&
                               ((nticks - last_tm) > MAVINTVL)
                               && msp.available && replayer == Player.NONE)
                            {
                                MWPLog.message("Restart poller on telemetry timeout\n");
/*                               have_api = have_vers = have_misc =
                                 =have_wp = have_nc = have_fcv = have_fcvv = */
                                have_status = false;
                                xbits = icount = api_cnt = 0;
                                init_sstats();
                                last_tm = 0;
                                lastp.start();
                                serstate = SERSTATE.NORMAL;
                                queue_cmd(msp_get_status/*MSP.Cmds.IDENT*/,null,0);
                                run_queue();
                            }
                        }
                    }
                    else
                        lastok = lastrx = nticks;

                    if((nticks % STATINTVL) == 0)
                    {
                        gen_serial_stats();
                        telemstatus.update(telstats, item_visible(DOCKLETS.TELEMETRY));
                    }
                }

                if(duration != 0 && duration != last_dura)
                {
                    int mins;
                    int secs;
                    if(duration < 0)
                    {
                        mins = secs = 0;
                        duration = 0;
                    }
                    else
                    {
                        mins = (int)duration / 60;
                        secs = (int)duration % 60;
                        if(mins != lmin)
                        {
                                navstatus.update_duration(mins);
                                lmin = mins;
                        }
                    }
                    elapsedlab.set_text("%02d:%02d".printf(mins,secs));
                    last_dura = duration;
                }
                return Source.CONTINUE;
            });
    }

    private void init_have_home()
    {
        have_home = false;
        markers.negate_home();
        ls.calc_mission(0);
        home_pos.lat = 0;
        home_pos.lon = 0;
        xlon = 0;
        xlat = 0;
        want_special = 0;
    }

    private void send_poll()
    {
        if(serstate == SERSTATE.POLLER)
        {
            var req=requests[tcycle];
            lastm = nticks;
            if (req == MSP.Cmds.ANALOG || req == MSP.Cmds.ANALOG2)
            {
                if (lastm - last_an > MAVINTVL)
                {
                    last_an = lastm;
                    mavc = 0;
                }
                else
                {
                    tcycle = (tcycle + 1) % requests.length;
                    req = requests[tcycle];
                }
            }
                // only is not armed
            if (req == MSP.Cmds.GPSSTATISTICS && armed == 1)
            {
                tcycle = (tcycle + 1) % requests.length;
                req = requests[tcycle];
            }
            queue_cmd(req, null, 0);
        }
    }

    private void init_craft_icon()
    {
        if(craft == null)
        {
            if(sport_device != null && dmrtype != 0 && vi.mrtype == 0)
                vi.mrtype = (uint8)dmrtype;
            MWPLog.message("init icon %d\n",  vi.mrtype);
            craft = new Craft(view, vi.mrtype,norotate, !no_trail,
                              stack_size, mod_points);
            craft.park();
            craft.adjust_z_order(markers.markers);
        }
    }

    private ulong build_pollreqs()
    {
        ulong reqsize = 0;
        requests.resize(0);

        sensor_alm = false;

        requests += msp_get_status;
        reqsize += (msp_get_status ==  MSP.Cmds.STATUS_EX) ? MSize.MSP_STATUS_EX :
            (msp_get_status ==  MSP.Cmds.INAV_STATUS) ? MSize.MSP2_INAV_STATUS :
            MSize.MSP_STATUS;


        if (msp_get_status ==  MSP.Cmds.INAV_STATUS)
        {
            requests += MSP.Cmds.ANALOG2;
            reqsize += MSize.MSP_ANALOG2;
        }
        else
        {
            requests += MSP.Cmds.ANALOG;
            reqsize += MSize.MSP_ANALOG;
        }

        sflags = NavStatus.SPK.Volts;

        var missing = 0;

        if(force_mag)
            usemag = true;
        else
        {
            usemag = ((sensor & MSP.Sensors.MAG) == MSP.Sensors.MAG);
            if(!usemag && Craft.is_mr(vi.mrtype))
                missing = MSP.Sensors.MAG;
        }

        if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS)
        {
            sflags |= NavStatus.SPK.GPS;
            if((navcap & NAVCAPS.NAVSTATUS) == NAVCAPS.NAVSTATUS)
            {
                requests += MSP.Cmds.NAV_STATUS;
                reqsize += MSize.MSP_NAV_STATUS;
            }
            requests += MSP.Cmds.RAW_GPS;
            requests += MSP.Cmds.COMP_GPS;

            if((navcap & NAVCAPS.NAVCONFIG) == 0)
            {
                requests += MSP.Cmds.GPSSTATISTICS;
                reqsize += MSize.MSP_GPSSTATISTICS;
            }
            reqsize += (MSize.MSP_RAW_GPS + MSize.MSP_COMP_GPS);
            init_craft_icon();
        }
        else
            missing |= MSP.Sensors.GPS;

        if((sensor & MSP.Sensors.ACC) == MSP.Sensors.ACC)
        {
            requests += MSP.Cmds.ATTITUDE;
            reqsize += MSize.MSP_ATTITUDE;
        }

        if(((sensor & MSP.Sensors.BARO) == MSP.Sensors.BARO) || Craft.is_fw(vi.mrtype))
        {
            sflags |= NavStatus.SPK.BARO;
            requests += MSP.Cmds.ALTITUDE;
            reqsize += MSize.MSP_ALTITUDE;
        }
        else
            missing |= MSP.Sensors.BARO;

        if(missing != 0)
        {
            if(gpscnt < 5)
            {
                string []nsensor={};
                if((missing & MSP.Sensors.GPS) != 0)
                    nsensor += "GPS";
                if((missing & MSP.Sensors.BARO) != 0)
                    nsensor += "BARO";
                if((missing & MSP.Sensors.MAG) != 0)
                    nsensor += "MAG";
                var nss = string.joinv("/",nsensor);
                set_error_status("No %s detected".printf(nss));
                MWPLog.message("no %s, sensor = 0x%x\n", nss, sensor);
                gpscnt++;
            }
        }
        else
        {
            set_error_status(null);
            gpscnt = 0;
        }
        return reqsize;
    }

    private void map_warn_set_text(bool init = false)
    {
        if(clutextg != null)
        {
            var parts= conf.wp_text.split("/");
            if(init)
            {
                var grey = Clutter.Color.from_string(parts[1]);
                clutextg.color = grey;
                clutextd.color = grey;
            }
            if(window_h != -1)
            {
                var tsplit = parts[0].split(" ");
                var th = int.parse(tsplit[1]);
                var ih = (((window_h * 15 / 100) + 4) / 8) * 8;
                if(ih < th)
                    parts[0] = "%s %d".printf(tsplit[0], ih);
            }
            clutextg.font_name = parts[0];
            clutextd.font_name = parts[0];
        }
    }

    private void map_init_warning(Clutter.LayoutManager lm)
    {
        Clutter.Color red = { 0xff,0,0, 0xff};

        var textb = new Clutter.Actor ();
        var textm = new Clutter.Actor ();
        var textd = new Clutter.Actor ();

        clutextr = new Clutter.Text.full ("Sans 36", "", red);
        clutextg = new Clutter.Text();
        clutextd = new Clutter.Text();
        map_warn_set_text(true);

        lm.child_set(view,textb,"x-align", Clutter.ActorAlign.START);
        lm.child_set(view,textb,"y-align", Clutter.ActorAlign.START);
        lm.child_set(view,textm,"x-align", Clutter.ActorAlign.END);
        lm.child_set(view,textm,"y-align", Clutter.ActorAlign.START);
        lm.child_set(view,textd,"x-align", Clutter.ActorAlign.END);
        lm.child_set(view,textd,"y-align", Clutter.ActorAlign.END);
        textb.add_child(clutextr);
        textm.add_child(clutextg);
        textd.add_child(clutextd);
        view.add_child (textb);
        view.add_child (textm);
        view.add_child (textd);
        map_clean = true;
        clutextg.use_markup = true;
        clutextd.use_markup = true;
    }

    private void map_show_warning(string text)
    {
        clutextr.set_text(text);
    }

    private void map_hide_warning()
    {
        clutextr.set_text("");
    }

    private void map_show_wp(string text)
    {
        clutextg.set_markup(text);
        map_clean = false;
    }

    private void map_show_dist(string text)
    {
        clutextd.set_markup(text);
        map_clean = false;
    }

    private void map_hide_wp()
    {
        if(!map_clean)
        {
            clutextg.set_text("");
            clutextd.set_text("");
            markers.clear_ring();
            map_clean = true;
        }
    }

    private void  alert_broken_sensors(uint8 val)
    {
        if(val != xs_state)
        {
            string sound;
            MWPLog.message("sensor health %04x %d %d\n", sensor, val, xs_state);
            if(val == 1)
            {
                sound = /*(sensor_alm) ? Alert.GENERAL :*/ Alert.RED;
                sensor_alm = true;
                init_craft_icon();
                map_show_warning("SENSOR FAILURE");
            }
            else
            {
                sound = Alert.GENERAL;
                map_hide_warning();
                hwstatus[0] = 1;
            }
            bleet_sans_merci(sound);
            navstatus.hw_failure(val);
            xs_state = val;
            if(serstate != SERSTATE.TELEM)
            {
                MWPLog.message("request sensor info\n");
                queue_cmd(MSP.Cmds.SENSOR_STATUS,null,0);
            }
        }
    }

    private void update_sensor_array()
    {
        alert_broken_sensors((uint8)(sensor >> 15));
        for(int i = 0; i < 5; i++)
        {
            uint16 mask = (1 << i);
            bool setx = ((sensor & mask) != 0);
            sensor_sts[i+1].label = "<span foreground = \"%s\">▌</span>".printf((setx) ? "green" : "red");
        }
        sensor_sts[0].label = sensor_sts[1].label;
    }

    private void clear_sensor_array()
    {
        xs_state = 0;
        for(int i = 0; i < 6; i++)
            sensor_sts[i].label = " ";
    }

    private void reboot_status()
    {
        set_menu_state("reboot", ((msp != null && msp.available && armed == 0)));
        set_menu_state("terminal", ((msp != null && msp.available && armed == 0)));
    }

    private void armed_processing(uint64 flag, string reason="")
    {
        if(armed == 0)
        {
            armtime = 0;
            duration = -1;
            if(replayer == Player.NONE)
                init_have_home();
            no_ofix = 0;
            gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};
        }
        else
        {
            if(armtime == 0)
                time_t(out armtime);

            if(replayer == Player.NONE)
            {
                time_t(out duration);
                duration -= armtime;
            }
        }

        if(Logger.is_logging)
        {
            Logger.armed((armed == 1), duration, flag,sensor, telem);
        }

        if(armed != larmed)
        {
            navstatus.set_replay_mode((replayer != Player.NONE));
            radstatus.annul();
            if (armed == 1)
            {
                magdt = -1;
                odo = {0};

                odo.alt = -9999;
                reboot_status();
                init_craft_icon();
                if(!no_trail)
                {
                    if(craft != null)
                    {
                        markers.remove_rings(view);
                        craft.init_trail();
                    }
                }
                init_have_home();
                MWPLog.message("Armed %x\n", want_special);
                armed_spinner.show();
                armed_spinner.start();
                sflags |= NavStatus.SPK.Volts;

                if (conf.audioarmed == true)
                {
                    audio_cb.active = true;
                }
                if(conf.logarmed == true)
                {
                    logb.active = true;
                }

                if(Logger.is_logging)
                {
                    Logger.armed(true,duration,flag, sensor,telem);
                    if(rhdop != 10000)
                    {
                        LTM_XFRAME xf = LTM_XFRAME();
                        xf = {0};
                        xf.hdop = rhdop;
                        xf.sensorok = (sensor >> 15);
                        Logger.ltm_xframe(xf);
                    }
                }
                odoview.dismiss();
            }
            else
            {
                if(odo.time > 5)
                {
                    MWPLog.message("Distance = %.1f, max speed = %.1f time = %u\n",
                                   odo.distance, odo.speed, odo.time);
                    odoview.display(odo, true);
                    map_hide_wp();
                }
                MWPLog.message("Disarmed %s\n", reason);
                armed_spinner.stop();
                armed_spinner.hide();
                markers.negate_ipos();
                duration = -1;
                armtime = 0;
                want_special = 0;
                init_have_home();
                if (conf.audioarmed == true)
                {
                    audio_cb.active = false;
                }
                if(conf.logarmed == true)
                {
                    if(Logger.is_logging)
                        Logger.armed(false,duration,flag, sensor,telem);
                    logb.active=false;
                }
                navstatus.reset_states();
                reboot_status();
            }
        }
        larmed = armed;
    }

    private void update_odo(double spd, double ddm)
    {
        odo.time = (uint)duration;
        odo.distance += ddm;
        if (spd > odo.speed)
            odo.speed = spd;
        if(NavStatus.cg.range > odo.range)
            odo.range = NavStatus.cg.range;
        double estalt = (double)NavStatus.alti.estalt/100.0;
        if (estalt > odo.alt)
         odo.alt = estalt;
    }

    private void reset_poller()
    {
        lastok = nticks;
        if(serstate != SERSTATE.NONE && serstate != SERSTATE.TELEM)
        {
            if(nopoll == false)
                serstate = SERSTATE.POLLER;
            msg_poller();
        }
    }

    private void gps_alert(uint8 scflags)
    {
        bool urgent = ((scflags & SAT_FLAGS.URGENT) != 0);
        bool beep = ((scflags & SAT_FLAGS.BEEP) != 0);
        navstatus.sats(_nsats, urgent);
        if(beep && replayer == Player.NONE)
            bleet_sans_merci(Alert.SAT);
        nsats = _nsats;
        last_ga = lastrx;
    }

    private void sat_coverage()
    {
        uint8 scflags = 0;
        if(nsats != _nsats)
        {
            if(_nsats < msats)
            {
                if(_nsats < nsats)
                {
                    scflags = SAT_FLAGS.URGENT|SAT_FLAGS.BEEP;
                }
                else if((lastrx - last_ga) > USATINTVL)
                {
                    scflags = SAT_FLAGS.URGENT;
                }
            }
            else
            {
                if(nsats < msats)
                    scflags = SAT_FLAGS.URGENT;
                else if((lastrx - last_ga) > UUSATINTVL)
                {
                    scflags = SAT_FLAGS.NEEDED;
                }
            }
        }

        if((scflags == 0) && ((lastrx - last_ga) > SATINTVL))
        {
            scflags = SAT_FLAGS.NEEDED;
        }

        if(scflags != SAT_FLAGS.NONE)
            gps_alert(scflags);
    }

    private void flash_gps()
    {
        gpslab.label = "<span foreground = \"%s\">⬤</span>".printf(conf.led);
        Timeout.add(50, () =>
            {
                gpslab.set_label("◯");
                return false;
            });
    }

    private string board_by_id()
    {
        string board = "mysteryFC";
        switch (vi.board)
        {
            case "SPEV":
                board = "SPRACINGF3EVO";
                break;
            case "MKF4":
                board = "MatekF4";
                break;
            case "MKF7":
                board = "MatekF7";
                break;
            case "OMNI":
                board = "OMNIBUS";
                break;
            case "RMDO":
                board = "RMDO";
                break;
            case "SRF3":
                board = "SPRACINGF3";
                break;
            case "AFNA":
                board = "NAZE";
                break;
            case "CC3D":
                board = "CC3D";
                break;
            case "FYF3":
                board = "FURYF3";
                break;
            case "AIR3":
                board = "AIRHEROF3";
                break;
            case "AWF3":
                board = "ALIENWIIF3";
                break;
            case "OLI1":
                board = "OLIMEXINO";
                break;
            case "OBSD":
                board = "OMNIBUSF4";
                break;
            case "OBF4":
                board = "OMNIBUSF4";
                break;
            case "BJF4":
                board = "BLUEJAYF4";
                break;
            case "CLBR":
                board = "COLIBRI_RACE";
                break;
            case "COLI":
                board = "COLIBRI";
                break;
            case "PIKO":
                board = "PIKOBLX";
                break;
            case "ABF4":
                board = "AIRBOTF4";
                break;
            case "CJM1":
                board = "CJMCU";
                break;
            case "SDF3":
                board = "STM32F3DISCOVERY";
                break;
            case "SPKY":
                board = "SPARKY";
                break;
            case "YPF4":
                board = "YUPIF4";
                break;
            case "PXR4":
                board = "PIXRACER";
                break;
            case "ANY7":
                board = "ANYFCF7";
                break;
            case "F4BY":
                board = "F4BY";
                break;
            case "CPM1":
                board = "CRAZEPONYMINI";
                break;
            case "MOTO":
                board = "MOTOLAB";
                break;
            case "EUF1":
                board = "EUSTM32F103RC";
                break;
            case "REF3":
                board = "RCEXPLORERF3";
                break;
            case "SPK2":
                board = "SPARKY2";
                break;
            case "REVO":
                board = "REVO";
                break;
            case "ANYF":
                board = "ANYFC";
                break;
            case "SRFM":
                board = "SPRACINGF3MINI";
                break;
            case "LUX" :
                board = "LUX_RACE";
                break;
            case "FDV1":
                board = "FISHDRONEF4";
                break;
            case "AFF3":
                board = "ALIENFLIGHTF3";
                break;
            case "103R":
                board = "PORT103R";
                break;
            case "CHF3":
                board = "CHEBUZZF3";
                break;
            case "QRKV":
                board = "QuarkVision";
                break;
        }
        return board;
    }

    private string get_arm_fail(uint32 af, char sep=',')
    {
        StringBuilder sb = new StringBuilder ();
        if(af == 0)
            sb.append("OK");
        else
        {
            for(var i = 0; i < 32; i++)
            {
                if((af & (1<<i)) != 0)
                {
                    if(i < arm_fails.length)
                    {
                        if (arm_fails[i] != null)
                        {
                            sb.append(arm_fails[i]);
                            if ((1 << i) == ARMFLAGS.ARMING_DISABLED_NAVIGATION_UNSAFE)
                            {
                                bool navmodes = true;

                                sb.append_c(sep);
                                if(gpsstats.eph > inav_max_eph_epv ||
                                    gpsstats.epv > inav_max_eph_epv)
                                {
                                    sb.append(" • EPH/EPV");
                                    sb.append_c(sep);
                                    navmodes = false;
                                }
                                if(_nsats < msats )
                                {
                                    sb.append_printf(" • %d satellites", _nsats);
                                    sb.append_c(sep);
                                    navmodes = false;
                                }
                                if(wpdist > 0)
                                {
                                    sb.append_printf(" • 1st wp distance %dm", wpdist);
                                    sb.append_c(sep);
                                    navmodes = false;
                                }

                                if(navmodes)
                                {
                                    sb.append(" • Nav mode engaged");
                                    sb.append_c(sep);
                                }
                            }
                            else
                                sb.append_c(sep);
                        }
                    }
                    else
                    {
                        sb.append_printf("Unknown(%d)", i);
                        sb.append_c(sep);
                    }
                }
            }
            if(sb.len > 0 && sep != '\n')
                sb.truncate(sb.len-1);
        }
        return sb.str;
    }

    private void handle_msp_status(uint8[]raw, uint len)
    {
        uint64 bxflag;
        uint64 lmask;

        deserialise_u16(raw+4, out sensor);
        if(msp_get_status != MSP.Cmds.INAV_STATUS)
        {
            uint32 bx32;
            deserialise_u32(raw+6, out bx32);
            bxflag = bx32;
        }
        else
            deserialise_u64(raw+13, out bxflag);

        lmask = (angle_mask|horz_mask);

        armed = ((bxflag & arm_mask) == arm_mask) ? 1 : 0;

        if (nopoll == true)
        {
            have_status = true;
            if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS)
            {
                sflags |= NavStatus.SPK.GPS;
                init_craft_icon();
            }
        }
        else
        {
            uint32 arm_flags;
            uint16 loadpct;
            if(msp_get_status != MSP.Cmds.STATUS)
            {
                if(msp_get_status == MSP.Cmds.STATUS_EX)
                {
                    uint16 xaf;
                    deserialise_u16(raw+13, out xaf);
                    arm_flags = xaf;
                    deserialise_u16(raw+11, out loadpct);
                    profile = raw[10];
                }
                else
                {
                    deserialise_u32(raw+9, out arm_flags);
                    deserialise_u16(raw+6, out loadpct);
                    profile = raw[8];
                }

                if(arm_flags != xarm_flags)
                {
                    xarm_flags = arm_flags;

                    string arm_msg = get_arm_fail(xarm_flags);
                    MWPLog.message("Arming flags: %s (%04x), load %d%% %s\n",
                                   arm_msg, xarm_flags, loadpct,
                                   msp_get_status.to_string());
                    if((arm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0)
                    {
                        arm_warn.show();
                    }
                    else
                    {
                        arm_warn.hide();
                    }
                }
            }
            else
                profile = raw[10];

            if(have_status == false)
            {
                have_status = true;
                StringBuilder sb0 = new StringBuilder ();
                foreach (MSP.Sensors sn in MSP.Sensors.all())
                {
                    if((sensor & sn) == sn)
                    {
                        sb0.append(sn.to_string());
                        sb0.append_c(' ');
                    }
                }
                update_sensor_array();
                MWPLog.message("Sensors: %s (%04x)\n", sb0.str, sensor);

                if(!prlabel)
                {
                    prlabel = true;
                    var lab = verlab.get_label();
                    StringBuilder sb = new StringBuilder();
                    sb.append(lab);
                    if(naze32 && vi.fc_api != 0)
                        sb.append_printf(" API %d.%d", vi.fc_api >> 8,vi.fc_api & 0xff);

                    if(navcap != NAVCAPS.NONE)
                        sb.append(" Nav");
                    sb.append_printf(" Pr %d", profile);
                    verlab.label = verlab.tooltip_text = sb.str;
                }

                want_special = 0;

                if(replayer == Player.NONE)
                {
                    MWPLog.message("switch val == %08x (%08x)\n", bxflag, lmask);
                    if(Craft.is_mr(vi.mrtype) && ((bxflag & lmask) == 0) && robj == null)
                    {
                        if(conf.checkswitches)
                            swd.run();
                    }
                    if((navcap & NAVCAPS.NAVCONFIG) == NAVCAPS.NAVCONFIG)
                        queue_cmd(MSP.Cmds.NAV_CONFIG,null,0);
                    else if((navcap & NAVCAPS.INAV_MR)!= 0)
                        queue_cmd(MSP.Cmds.NAV_POSHOLD,null,0);
                    else if((navcap & NAVCAPS.INAV_FW) != 0)
                        queue_cmd(MSP.Cmds.FW_CONFIG,null,0);
                }

                var reqsize = build_pollreqs();
                var nreqs = requests.length;
                    // data we send, response is structs + this
                var qsize = nreqs * 6;
                reqsize += qsize;
                if(naze32)
                    qsize += 1; // for WP no

                MWPLog.message("Timer cycle for %d items, %lu => %lu bytes\n",
                               nreqs,qsize,reqsize);

                if(nopoll == false && nreqs > 0)
                {
                    if  (replayer == Player.NONE)
                    {
                        MWPLog.message("Start poller\n");
                        tcycle = 0;
                        lastm = nticks;
                        serstate = SERSTATE.POLLER;
                        start_audio();
                    }
                }
                report_bits(bxflag);
                Craft.RMIcon ri = 0;
                if ((rth_mask != 0) && ((bxflag & rth_mask) == 0))
                    ri |= Craft.RMIcon.RTH;
                if ((ph_mask != 0) && ((bxflag & ph_mask) == 0))
                    ri |= Craft.RMIcon.PH;
                if ((wp_mask != 0) && ((bxflag & wp_mask) == 0))
                    ri |= Craft.RMIcon.WP;
                if(ri != 0 && craft != null)
                    craft.remove_special(ri);
            }
            else
            {
                if(gpscnt != 0 && ((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS))
                {
                    build_pollreqs();
                }
                if(sensor != xsensor)
                {
                    update_sensor_array();
                    xsensor = sensor;
                }
            }

                // acro/horizon/angle changed

            if((bxflag & lmask) != (xbits & lmask))
            {
                report_bits(bxflag);
            }

            if(armed != 0)
            {
                if ((rth_mask != 0) &&
                    ((bxflag & rth_mask) != 0) &&
                    ((xbits & rth_mask) == 0))
                {
                    MWPLog.message("set RTH on %08x %u %ds\n", bxflag,bxflag,
                                   (int)duration);
                    want_special |= POSMODE.RTH;
                }
                else if ((ph_mask != 0) &&
                         ((bxflag & ph_mask) != 0) &&
                         ((xbits & ph_mask) == 0))
                {
                    MWPLog.message("set PH on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.PH;
                }
                else if ((wp_mask != 0) &&
                         ((bxflag & wp_mask) != 0) &&
                         ((xbits & wp_mask) == 0))
                {
                    MWPLog.message("set WP on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.WP;
                }
                else if ((xbits != bxflag) && craft != null)
                {
                    craft.set_normal();
                }
            }
            xbits = bxflag;
        }
        armed_processing(bxflag,"msp");
    }

    private void centre_mission(Mission ms, bool ctr_on)
    {
        MissionItem [] mis = ms.get_ways();
        if(mis.length > 0)
        {
            ms.maxx = ms.maxy = -999.0;
            ms.minx = ms.miny = 999.0;
            foreach(MissionItem mi in mis)
            {
                if(mi.action != MSP.Action.RTH &&
                   mi.action != MSP.Action.JUMP &&
                   mi.action != MSP.Action.SET_HEAD)
                {
                    if (mi.lat > ms.maxy)
                        ms.maxy = mi.lat;
                    if (mi.lon > ms.maxx)
                        ms.maxx = mi.lon;
                    if (mi.lat <  ms.miny)
                        ms.miny = mi.lat;
                    if (mi.lon <  ms.minx)
                        ms.minx = mi.lon;
                }
            }

            ms.cy = (ms.maxy + ms.miny) / 2.0;
            ms.cx = (ms.maxx + ms.minx) / 2.0;
            ms.zoom = guess_appropriate_zoom(bb_from_mission(ms));
            if (ctr_on)
            {
                map_centre_on(ms.cy, ms.cx);
                set_view_zoom(ms.zoom);
            }
        }
    }

    private void map_centre_on(double y, double x)
    {
        view.center_on(ly=y, lx=x);
        anim_cb();
    }

    private void check_mission_safe(double mlat, double mlon)
    {
        wpdist = 0;
        if(GPSInfo.nsat >= msats)
        {
            var sb = new StringBuilder();
            double dist,cse;
            Geo.csedist(
                GPSInfo.lat, GPSInfo.lon,
                mlat, mlon,
                out dist, out cse);
            dist *= 1852.0;
            sb.append_printf("To WP1: %.1fm", dist);
            if (nav_wp_safe_distance > 0)
            {
                double nsd = nav_wp_safe_distance/100.0;
                sb.append_printf(", nav_wp_safe_distance %.0fm", nsd);
                if(dist > nsd)
                {
                    mwp_warning_box(
                        "Nav WP Safe Distance exceeded : %.0fm >= %.0fm".printf(dist, nsd), Gtk.MessageType.ERROR,60);
                    wpdist = (int)dist;
                }
            }
            sb.append_c('\n');
            MWPLog.message(sb.str);
        }
    }

    private void try_centre_on(double xlat, double xlon)
    {
        if(!view.get_bounding_box().covers(xlat, xlon))
        {
            var mlat = view.get_center_latitude();
            var mlon = view.get_center_longitude();
            double alat, alon;
            double msize = Math.fmin(mapsize.width, mapsize.height);
            double dist,_cse;
            Geo.csedist(xlat, xlon, mlat, mlon, out dist, out _cse);

            if(dist * 1852.0 > msize)
            {
                alat = xlat;
                alon = xlon;
            }
            else
            {
                alat = (mlat + xlat)/2.0;
                alon = (mlon + xlon)/2.0;
            }
            map_centre_on(alat,alon);
        }
    }

    private bool update_pos_info()
    {
        bool pv;
        pv = pos_valid(GPSInfo.lat, GPSInfo.lon);
        if(pv == true)
        {
            if(follow == true)
            {
                if (centreon == true)
                {
                    if(conf.use_legacy_centre_on)
                        map_centre_on(GPSInfo.lat,GPSInfo.lon);
                    else
                        try_centre_on(GPSInfo.lat,GPSInfo.lon);
                }
                double cse = (usemag || ((replayer & Player.MWP) == Player.MWP)) ? mhead : GPSInfo.cse;
                craft.set_lat_lon(GPSInfo.lat, GPSInfo.lon,cse);
            }
        }
        return pv;
    }

    private void show_wp_distance(uint8 np)
    {
        if (wp_resp.length == NavStatus.nm_pts)
        {
            uint fs=(uint)conf.wp_dist_fontsize*1024;
            np = np - 1;
            var lat = wp_resp[np].lat;
            var lon = wp_resp[np].lon;
            if(lat == 0.0 && lon == 0.0)
            {
                lat = home_pos.lat;
                lon = home_pos.lon;
            }
            double dist,cse;
            Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                        lat, lon, out dist, out cse);
            StringBuilder sb = new StringBuilder();
            dist *= 1852.0;
            var icse = Math.lrint(cse) % 360;
            sb.append_printf("<span size=\"%u\">%.1fm %ld°", fs, dist, icse);
            if(GPSInfo.spd > 0.0 && dist > 1.0)
                sb.append_printf(" %ds", (int)(dist/GPSInfo.spd));
            else
                sb.append(" --s");
            sb.append("</span>");
            map_show_dist(sb.str);
        }
    }

    MissionItem wp_to_mitem(MSP_WP w)
    {
        MissionItem m = MissionItem();
        m.no= w.wp_no;
        m.action = (MSP.Action)w.action;
        m.lat = w.lat/10000000.0;
        m.lon = w.lon/10000000.0;
        m.alt = w.altitude/100;
        m.param1 = w.p1;
        if(m.action == MSP.Action.SET_HEAD &&
           conf.recip_head  == true && m.param1 != -1)
        {
            m.param1 = (m.param1 + 180) % 360;
        }
        m.param2 = w.p2;
        m.param3 = w.p3;
        return m;
    }

    void handle_wp_processing(uint8[] raw, uint len)
    {
        have_wp = true;
        MSP_WP w = MSP_WP();
        uint8* rp = raw;
        if((wpmgr.wp_flag & WPDL.CANCEL) != 0)
            return;

        if((wpmgr.wp_flag & WPDL.POLL) == 0)
        {
            w.wp_no = *rp++;
            w.action = *rp++;
            rp = deserialise_i32(rp, out w.lat);
            rp = deserialise_i32(rp, out w.lon);
            rp = deserialise_i32(rp, out w.altitude);
            rp = deserialise_i16(rp, out w.p1);
            rp = deserialise_u16(rp, out w.p2);
            rp = deserialise_u16(rp, out w.p3);
            w.flag = *rp;
        }

        if(w.wp_no == 1)
            wp_resp = {};

        if ((wpmgr.wp_flag & WPDL.VALIDATE) != 0  ||
            (wpmgr.wp_flag & WPDL.SAVE_EEPROM) != 0)
        {
            WPFAIL fail = WPFAIL.OK;
            validatelab.set_text("WP:%3d".printf(w.wp_no));
            if(w.wp_no != wpmgr.wps[wpmgr.wpidx].wp_no)
                fail |= WPFAIL.NO;
            else if(w.action != wpmgr.wps[wpmgr.wpidx].action)
                fail |= WPFAIL.ACT;
            else if (w.lat != wpmgr.wps[wpmgr.wpidx].lat)
                fail |= WPFAIL.LAT;
            else if (w.lon != wpmgr.wps[wpmgr.wpidx].lon)
                fail |= WPFAIL.LON;
            else if (w.altitude != wpmgr.wps[wpmgr.wpidx].altitude)
                fail |= WPFAIL.ALT;
            else if (w.p1 != wpmgr.wps[wpmgr.wpidx].p1)
                fail |= WPFAIL.P1;
            else if (w.p2 != wpmgr.wps[wpmgr.wpidx].p2)
                fail |= WPFAIL.P2;
            else if (w.p3 != wpmgr.wps[wpmgr.wpidx].p3)
                fail |= WPFAIL.P3;
            else if (w.flag != wpmgr.wps[wpmgr.wpidx].flag)
            {
                fail |= WPFAIL.FLAG;
            }

            if (fail != WPFAIL.OK)
            {
                remove_tid(ref upltid);
                if((debug_flags & DEBUG_FLAGS.WP) != DEBUG_FLAGS.NONE)
                {
                    stderr.printf("WP size %d [read,expect]\n", (int)len);
                    stderr.printf("no %d %d\n",
                                  w.wp_no, wpmgr.wps[wpmgr.wpidx].wp_no);
                    stderr.printf("action %d %d\n",
                                  w.action, wpmgr.wps[wpmgr.wpidx].action);
                    stderr.printf("lat %d %d\n",
                                  w.lat, wpmgr.wps[wpmgr.wpidx].lat);
                    stderr.printf("lon %d %d\n",
                                  w.lon, wpmgr.wps[wpmgr.wpidx].lon);
                    stderr.printf("alt %u %u\n",
                                  w.altitude, wpmgr.wps[wpmgr.wpidx].altitude);
                    stderr.printf("p1 %d %d\n",
                                  w.p1, wpmgr.wps[wpmgr.wpidx].p1);
                    stderr.printf("p2 %d %d\n",
                                  w.p2, wpmgr.wps[wpmgr.wpidx].p2);
                    stderr.printf("p3 %d %d\n",
                                  w.p3, wpmgr.wps[wpmgr.wpidx].p3);
                    stderr.printf("flag %x %x\n",
                                  w.flag, wpmgr.wps[wpmgr.wpidx].flag);
                }
                StringBuilder sb = new StringBuilder();
                for(var i = 0; i < failnames.length; i += 1)
                {
                    if ((fail & (1 <<i)) == (1 << i))
                    {
                        sb.append(failnames[i]);
                        sb.append_c(' ');
                    }
                }
                MWPCursor.set_normal_cursor(window);
                reset_poller();
                var mtxt = "Validation for wp %d fails for %s".printf(w.wp_no, sb.str);
                bleet_sans_merci(Alert.GENERAL);
                validatelab.set_text("⚠"); // u+26a0
                mwp_warning_box(mtxt, Gtk.MessageType.ERROR);
                if((wpmgr.wp_flag & WPDL.CALLBACK) != 0)
                    upload_callback(-1);
            }
            else if(w.flag != 0xa5)
            {
                wp_resp += wp_to_mitem(w);
                wpmgr.wpidx++;
                uint8 wtmp[64];
                var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
                queue_cmd(MSP.Cmds.SET_WP, wtmp, nb);
            }
            else
            {
                wp_resp += wp_to_mitem(w);
                remove_tid(ref upltid);
                MWPCursor.set_normal_cursor(window);
                bleet_sans_merci(Alert.GENERAL);
                validatelab.set_text("✔"); // u+2714
                if((wpmgr.wp_flag & WPDL.CALLBACK) != 0)
                    upload_callback(wpmgr.wps.length);
                if(vi.fc_api < APIVERS.mspV2)
                    mwp_warning_box("Mission validated", Gtk.MessageType.INFO,5);
                NavStatus.have_rth = ((MSP.Action)w.action == MSP.Action.RTH);
                NavStatus.nm_pts = (uint8)wpmgr.wps.length;
                MWPLog.message("Mission validated (points: %u, RTH: %s)\n",
                               NavStatus.nm_pts,
                               NavStatus.have_rth.to_string());
                if((wpmgr.wp_flag & WPDL.SAVE_EEPROM) != 0)
                {
                    uint8 zb=42;
                    MWPLog.message("Saving mission\n");
                    queue_cmd(MSP.Cmds.WP_MISSION_SAVE, &zb, 1);
                }
                wpmgr.wp_flag |= WPDL.GETINFO;
                if(inav)
                    queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
                reset_poller();
                if (downgrade != 0)
                {
                    MWPLog.message("Requesting downgraded mission\n");
                    download_mission();
                }
                else if(wpmgr.wps.length > 0  &&
                        (MSP.Action)wpmgr.wps[0].action == MSP.Action.WAYPOINT)
                    check_mission_safe(wpmgr.wps[0].lat/10000000.0,  wpmgr.wps[0].lon/10000000.0);
            }
        }
        else if ((wpmgr.wp_flag & WPDL.REPLACE) != 0 ||
                 (wpmgr.wp_flag & WPDL.REPLAY) != 0)
        {
            validatelab.set_text("WP:%3d".printf(w.wp_no));
            var m = wp_to_mitem(w);
            wp_resp += m;
            if(w.flag == 0xa5 || w.wp_no == 255)
            {
                remove_tid(ref upltid);
                MWPCursor.set_normal_cursor(window);
                var ms = new Mission();
                if(w.wp_no == 1 && m.action == MSP.Action.RTH
                   && w.lat == 0 && w.lon == 0)
                {
                    ls.clear_mission();
                }
                else
                {
                    ms.set_ways(wp_resp);
                    ls.import_mission(ms, (conf.rth_autoland &&
                                           Craft.is_mr(vi.mrtype)));
                    centre_mission(ms, !centreon);
                    markers.add_list_store(ls);
                    validatelab.set_text("✔"); // u+2714
                    if (wp_resp[0].action == MSP.Action.WAYPOINT)
                        check_mission_safe(wp_resp[0].lat,wp_resp[0].lon);

                    NavStatus.have_rth = ((MSP.Action)w.action == MSP.Action.RTH);
                    NavStatus.nm_pts = (uint8)w.wp_no;
                    MWPLog.message("Mission restore (points: %u, RTH: %s)\n",
                                   NavStatus.nm_pts,
                                   NavStatus.have_rth.to_string());
                }
                wp_resp={};
                reset_poller();
            }
            else if(w.flag == 0xfe)
            {
                remove_tid(ref upltid);
                MWPCursor.set_normal_cursor(window);
                MWPLog.message("Error flag on wp #%d\n", w.wp_no);
                reset_poller();
            }
            else
            {
                request_wp(w.wp_no+1);
            }
        }
        else
        {
            MWPCursor.set_normal_cursor(window);
            remove_tid(ref upltid);
            MWPLog.message("unsolicited WP #%d\n", w.wp_no);
            reset_poller();
        }
    }


    private void process_msp_analog(MSP_ANALOG an)
    {
        if(have_mspradio)
            an.rssi = 0;
        else
            radstatus.update_rssi(an.rssi, item_visible(DOCKLETS.RADIO));
        curr.centiA = an.amps;
        curr.mah = an.powermetersum;
        if(curr.centiA != 0 || curr.mah != 0)
        {
            curr.ampsok = true;
            navstatus.current(curr, 2);
            if (curr.centiA > odo.amps)
                odo.amps = curr.centiA;
        }
        if(Logger.is_logging)
        {
            Logger.analog(an);
        }
        set_bat_stat(an.vbat);
    }

    public void handle_serial(MSP.Cmds cmd, uint8[] raw, uint len,
                              uint8 xflags, bool errs)
    {
        if(cmd >= MSP.Cmds.LTM_BASE)
        {
            telem = true;
            if (replayer != Player.MWP && cmd != MSP.Cmds.MAVLINK_MSG_ID_RADIO)
            {
                if (errs == false)
                {
                    if(last_tm == 0)
                    {
                        var mtype= (cmd >= MSP.Cmds.MAV_BASE) ? "MAVlink" : "LTM";
                        MWPLog.message("%s telemetry\n", mtype);
                        serstate = SERSTATE.TELEM;
                        init_sstats();
                        if(naze32 != true)
                        {
                            naze32 = true;
                            mwvar = vi.fctype = MWChooser.MWVAR.CF;
                            var vers="iNav Telemetry";
                            verlab.label = verlab.tooltip_text = vers;
                        }
                    }
                    last_tm = nticks;
                    last_gps = nticks;
                    if(last_tm == 0)
                        last_tm =1;
                }
            }
        }

        if(errs == true)
        {
            lastrx = lastok = nticks;
            MWPLog.message("Error on cmd %s %d\n", cmd.to_string(), cmd);
            switch(cmd)
            {
                case MSP.Cmds.NAME:
                case MSP.Cmds.INAV_MIXER:
                    queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
                    run_queue();
                    break;
                case MSP.Cmds.NAV_CONFIG:
                    navcap = NAVCAPS.NONE;
                    break;
                case MSP.Cmds.API_VERSION:
                    queue_cmd(MSP.Cmds.BOXNAMES, null,0);
                    run_queue();
                    break;
                case MSP.Cmds.IDENT:
                    queue_cmd(MSP.Cmds.API_VERSION, null,0);
                    run_queue();
                    break;
                case MSP.Cmds.WP_MISSION_LOAD:
                case MSP.Cmds.MISC:
                    queue_cmd(msp_get_status,null,0);
                    run_queue();
                    break;
                case MSP.Cmds.INAV_STATUS:
                case MSP.Cmds.BOX: // e.g. ACTIVEBOXES
                    msp_get_status = MSP.Cmds.STATUS_EX;
                    queue_cmd(msp_get_status,null,0);
                    run_queue();
                    break;
                case MSP.Cmds.STATUS_EX:
                    msp_get_status = MSP.Cmds.STATUS;
                    queue_cmd(msp_get_status,null,0);
                    run_queue();
                    break;
                case  MSP.Cmds.WP_GETINFO:
                case  MSP.Cmds.COMMON_SETTING:
                case  MSP.Cmds.SET_RTC:
                    run_queue();
                    break;
                case MSP.Cmds.COMMON_SET_TZ:
                    rtcsecs = 0;
                    queue_cmd(MSP.Cmds.BUILD_INFO, null, 0);
                    run_queue();
                    break;
                default:
                    queue_cmd(msp_get_status,null,0);
                    run_queue();
                    break;
            }
            return;
        }
        else if(((debug_flags & DEBUG_FLAGS.MSP) != DEBUG_FLAGS.NONE) && cmd < MSP.Cmds.LTM_BASE)
        {
            MWPLog.message("Process MSP %s\n", cmd.to_string());
        }

        if(fwddev != null && fwddev.available)
        {
            if(cmd < MSP.Cmds.LTM_BASE && conf.forward == FWDS.ALL)
            {
                fwddev.send_command(cmd, raw, len);
            }
            if(cmd >= MSP.Cmds.LTM_BASE && cmd < MSP.Cmds.MAV_BASE)
            {
                if (conf.forward == FWDS.LTM || conf.forward == FWDS.ALL ||
                    (conf.forward == FWDS.minLTM &&
                     (cmd == MSP.Cmds.TG_FRAME ||
                      cmd == MSP.Cmds.TA_FRAME ||
                      cmd == MSP.Cmds.TS_FRAME )
                     ))
                fwddev.send_ltm((cmd - MSP.Cmds.LTM_BASE), raw, len);
            }
            if(cmd >= MSP.Cmds.MAV_BASE &&
               (conf.forward == FWDS.ALL ||
                (conf.forward == FWDS.minLTM &&
                 (cmd == MSP.Cmds.MAVLINK_MSG_ID_HEARTBEAT ||
                  cmd == MSP.Cmds.MAVLINK_MSG_ID_SYS_STATUS ||
                  cmd == MSP.Cmds.MAVLINK_MSG_GPS_RAW_INT ||
                  cmd == MSP.Cmds.MAVLINK_MSG_VFR_HUD ||
                  cmd == MSP.Cmds.MAVLINK_MSG_ATTITUDE ||
                  cmd == MSP.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW))))
            {
                fwddev.send_mav((cmd - MSP.Cmds.MAV_BASE), raw, len);
            }
        }

        if(Logger.is_logging)
            Logger.log_time();

        if(cmd != MSP.Cmds.RADIO)
        {
            lastrx = lastok = nticks;
            if(rxerr)
            {
                set_error_status(null);
                rxerr=false;
            }
        }

        switch(cmd)
        {
            case MSP.Cmds.API_VERSION:
                have_api = true;
                if(len > 32)
                {
                    naze32 = true;
                    mwvar = vi.fctype = MWChooser.MWVAR.CF;
                    var vers="CF mwc %03d".printf(vi.mvers);
                    verlab.label = verlab.tooltip_text = vers;
                    queue_cmd(MSP.Cmds.BOXNAMES,null,0);
                }
                else
                {
                    vi.fc_api = raw[1] << 8 | raw[2];
                    xarm_flags = 0xffff;
                    if (vi.fc_api >= APIVERS.mspV2)
                    {
                        msp.use_v2 = true;
                        MWPLog.message("Using MSP v2\n");
                        queue_cmd(MSP.Cmds.NAME,null,0);
                    }
                    else
                        queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
                }
                break;

            case MSP.Cmds.NAME:
                raw[len] = 0;
                vname = (string)raw;
                MWPLog.message("Model name: \"%s\"\n", vname);
                int mx = mmap.get_model_type(vname);
                if (mx != 0)
                {
                    vi.mrtype = (uint8)mx;
                    queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
                }
                else
                    if (vi.fc_api >= APIVERS.mixer)
                        queue_cmd(MSP.Cmds.INAV_MIXER,null,0);
                    else
                        queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
                set_typlab();
                break;

            case MSP.Cmds.INAV_MIXER:
                uint16 hx;
                hx = raw[6]<<8|raw[5];
                MWPLog.message("V2 mixer %u %u\n", raw[5], raw[3]);
                if(hx != 0 && hx < 0xff)
                    vi.mrtype = raw[5]; // legacy types only
                else
                {
                    switch(raw[3])
                    {
                        case 0:
                            vi.mrtype = 3;
                            break;
                        case 1:
                            vi.mrtype = 8;
                            break;
                        case 3:
                            vi.mrtype = 1;
                            break;
                        default:
                            break;
                    }
                 }
                 queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
                 break;

            case MSP.Cmds.COMMON_SET_TZ:
                rtcsecs = 0;
                queue_cmd(MSP.Cmds.BUILD_INFO, null, 0);
                break;

            case MSP.Cmds.RTC:
                uint16 millis;
                uint8* rp = raw;
                rp = deserialise_i32(rp, out rtcsecs);
                deserialise_u16(rp, out millis);
                var now = new DateTime.now_local();
                uint16 locmillis = (uint16)(now.get_microsecond()/1000);
                var rem = new DateTime.from_unix_local((int64)rtcsecs);
                string loc = "RTC local %s.%03u, fc %s.%03u\n".printf(
                    now.format("%FT%T"),
                    locmillis,
                    rem.format("%FT%T"), millis);

                if(rtcsecs == 0)
                {
                    uint8 tbuf[6];
                    rtcsecs = (uint32)now.to_unix();
                    serialise_u32(tbuf, rtcsecs);
                    serialise_u16(tbuf+4, locmillis);
                    queue_cmd(MSP.Cmds.SET_RTC,tbuf, 6);
                    run_queue();
                }

                MWPLog.message(loc);

                if(need_mission)
                {
                    need_mission = false;
                    if(conf.auto_restore_mission)
                    {
                        MWPLog.message("Auto-download FC mission\n");
                        download_mission();
                    }
                }
                break;

            case MSP.Cmds.BOARD_INFO:
                raw[4]=0;
                vi.board = (string)raw[0:3];
                if(len > 8)
                {
                    raw[len] = 0;
                    vi.name = (string)raw[9:len];
                }
                else
                    vi.name = null;
                queue_cmd(MSP.Cmds.FC_VARIANT,null,0);
                break;

            case MSP.Cmds.FC_VARIANT:
                naze32 = true;
                raw[4] = 0;
                inav = false;
                vi.fc_var = (string)raw[0:4];
                if (have_fcv == false)
                {
                    have_fcv = true;
                    switch(vi.fc_var)
                    {
                        case "CLFL":
                        case "BTFL":
                            vi.fctype = mwvar = MWChooser.MWVAR.CF;
                            queue_cmd(MSP.Cmds.FC_VERSION,null,0);
                            break;
                        case "INAV":
                            navcap = NAVCAPS.WAYPOINTS|NAVCAPS.NAVSTATUS;
                            if (Craft.is_mr(vi.mrtype))
                                navcap |= NAVCAPS.INAV_MR;
                            else
                                navcap |= NAVCAPS.INAV_FW;

                            vi.fctype = mwvar = MWChooser.MWVAR.CF;
                            inav = true;
                            queue_cmd(MSP.Cmds.FEATURE,null,0);
                            break;
                        default:
                            queue_cmd(MSP.Cmds.BOXNAMES,null,0);
                            break;
                    }
                }
                break;

            case MSP.Cmds.FEATURE:
                uint32 fmask;
                deserialise_u32(raw, out fmask);
                bool curf = (fmask & MSP.Feature.CURRENT) != 0;
                MWPLog.message("Feature Mask [%08x] : telemetry %s, gps %s, current %s\n",
                               fmask,
                               (0 != (fmask & MSP.Feature.TELEMETRY)).to_string(),
                               (0 != (fmask & MSP.Feature.GPS)).to_string(),
                               curf.to_string());

                if (curf == false)
                    navstatus.amp_hide(true);

                if(conf.need_telemetry && (0 == (fmask & MSP.Feature.TELEMETRY)))
                    mwp_warning_box("TELEMETRY requested but not enabled in iNav", Gtk.MessageType.ERROR);
                queue_cmd(MSP.Cmds.BLACKBOX_CONFIG,null,0);
                break;

            case MSP.Cmds.BLACKBOX_CONFIG:
                MSP.Cmds next = MSP.Cmds.FC_VERSION;
                if (raw[0] == 1 && raw[1] == 1)  // enabled and sd flash
                    next = MSP.Cmds.DATAFLASH_SUMMARY;
                queue_cmd(next,null,0);
                break;

            case MSP.Cmds.DATAFLASH_SUMMARY:
                uint32 fsize;
                uint32 used;
                deserialise_u32(raw+5, out fsize);
                deserialise_u32(raw+9, out used);
                if(fsize > 0)
                {
                    var pct = 100 * used  / fsize;
                    MWPLog.message ("Data Flash %u /  %u (%u%%)\n", used, fsize, pct);
                    if(conf.flash_warn > 0 && pct > conf.flash_warn)
                        mwp_warning_box("Data flash is %u%% full".printf(pct),
                                        Gtk.MessageType.WARNING);
                }
                else
                    MWPLog.message("Flash claims to be 0 bytes!!\n");

                queue_cmd(MSP.Cmds.FC_VERSION,null,0);
                break;

            case MSP.Cmds.FC_VERSION:
                if(have_fcvv == false)
                {
                    have_fcvv = true;
                    set_menu_state("reboot", true);
                    set_menu_state("terminal", true);
                    vi.fc_vers = raw[0] << 16 | raw[1] << 8 | raw[2];
                    var fcv = "%s v%d.%d.%d".printf(vi.fc_var,raw[0],raw[1],raw[2]);
                    verlab.label = verlab.tooltip_text = fcv;
                    if(inav)
                    {
                        if(vi.fc_vers < FCVERS.hasMoreWP)
                            wp_max = 15;
                        else if (vi.board != "AFNA" && vi.board != "CC3D")
                            wp_max = 60;
                        else
                            wp_max = 30;

                        mission_eeprom = (vi.board != "AFNA" &&
                                          vi.board != "CC3D" &&
                                          vi.fc_vers >= FCVERS.hasEEPROM);
                        msp_get_status = (vi.fc_api < 0x200) ? MSP.Cmds.STATUS :
                            (vi.fc_vers >= FCVERS.hasV2STATUS) ? MSP.Cmds.INAV_STATUS : MSP.Cmds.STATUS_EX;
                        if (vi.fc_api >= APIVERS.mspV2 && vi.fc_vers >= FCVERS.hasTZ && conf.adjust_tz)
                        {
                            var dt = new DateTime.now_local();
                            int16 tzoffm = (short)((int64)dt.get_utc_offset()/(1000*1000*60));
                            if(tzoffm != 0)
                            {
                                MWPLog.message("set TZ offset %d\n", tzoffm);
                                queue_cmd(MSP.Cmds.COMMON_SET_TZ, &tzoffm, sizeof(int16));
                            }
                            else
                                queue_cmd(MSP.Cmds.BUILD_INFO, null, 0);
                        }
                        else
                            queue_cmd(MSP.Cmds.BUILD_INFO, null, 0); //?BOXNAMES?
                    }
                    else
                        queue_cmd(MSP.Cmds.BOXNAMES,null,0);
                }
                break;

            case MSP.Cmds.BUILD_INFO:
                if(len > 18)
                {
                    uint8 gi[16] = raw[19:len];
                    gi[len-19] = 0;
                    vi.fc_git = (string)gi;
                }
                uchar vs[4];
                serialise_u32(vs, vi.fc_vers);
                if(vi.name == null)
                    vi.name = board_by_id();
                var vers = "%s v%d.%d.%d  %s (%s)".printf(vi.fc_var,
                                                          vs[2],vs[1],vs[0],
                                                          vi.name, vi.fc_git);
                verlab.label = verlab.tooltip_text = vers;
                MWPLog.message("%s\n", vers);
                queue_cmd(MSP.Cmds.BOXNAMES,null,0);
                break;

            case MSP.Cmds.IDENT:
                last_gps = 0;
                have_vers = true;
                bat_annul();
                hwstatus[0]=1;

                for(var j = 1; j < 9; j++)
                    hwstatus[j] = 0;
                if (icount == 0)
                {
                    vi = {0};
                    vi.mvers = raw[0];
                    vi.mrtype = raw[1];
                    if(dmrtype != 0)
                        vi.mrtype = (uint8)dmrtype;

                    prlabel = false;

                    deserialise_u32(raw+3, out capability);

                    MWPLog.message("set mrtype=%u cap =%x\n", vi.mrtype, raw[3]);
                    MWChooser.MWVAR _mwvar = mwvar;

                    if(mwvar == MWChooser.MWVAR.AUTO)
                    {
                        naze32 = ((capability & MSPCaps.CAP_PLATFORM_32BIT) != 0);
                    }
                    else
                    {
                        naze32 = mwvar == MWChooser.MWVAR.CF;
                    }

                    if(naze32 == true)
                    {
                        if(force_nc == false)
                            navcap = NAVCAPS.NONE;
}
                    else
                    {
                        navcap = ((raw[3] & 0x10) == 0x10) ?
                            NAVCAPS.WAYPOINTS|NAVCAPS.NAVSTATUS|NAVCAPS.NAVCONFIG
                            : NAVCAPS.NONE;
                        set_menu_state("reboot", false);
                        set_menu_state("terminal", false);
                    }
                    if(mwvar == MWChooser.MWVAR.AUTO)
                    {
                        if(naze32)
                        {
                            _mwvar = MWChooser.MWVAR.CF;
                        }
                        else
                        {
                            _mwvar = (navcap != NAVCAPS.NONE) ? MWChooser.MWVAR.MWNEW : MWChooser.MWVAR.MWOLD;
                            wp_max = 30; // safety net
                        }
                    }
                    vi.fctype = mwvar;
                    var vers="MWvers v%03d".printf(vi.mvers);
                    verlab.label = verlab.tooltip_text = vers;
                    queue_cmd(MSP.Cmds.API_VERSION,null,0);
                }
                icount++;
                break;

            case MSP.Cmds.BOXNAMES:
                if(replayer == Player.NONE)
                {
                    var ncbits = (navcap & (NAVCAPS.NAVCONFIG|NAVCAPS.INAV_MR|NAVCAPS.INAV_FW));
                    if(navcap != NAVCAPS.NONE)
                    {
                        set_menu_state("upload-mission", true);
                        set_menu_state("download-mission", true);
                    }

                    if (ncbits != 0)
                    {
                        set_menu_state("navconfig", true);
                        if(mission_eeprom)
                        {
                            set_menu_state("restore-mission", true);
                            set_menu_state("store-mission", true);
                            set_menu_state("mission-info", true);
                        }

                        MWPLog.message("Generate navconf %x\n", navcap);
                        navconf.setup(ncbits);
                        if((navcap & NAVCAPS.NAVCONFIG) == NAVCAPS.NAVCONFIG)
                            navconf.mw_navconf_event.connect((mw,nc) => {
                                    mw_update_config(nc);
                                });
                        if((navcap & NAVCAPS.INAV_MR) == NAVCAPS.INAV_MR)
                            navconf.mr_nav_poshold_event.connect((mw,pcfg) => {
                                    mr_update_config(pcfg);
                                });
                        if((navcap & NAVCAPS.INAV_FW) == NAVCAPS.INAV_FW)
                            navconf.fw_config_event.connect((mw,fw) => {
                                    fw_update_config(fw);
                                });
                    }
                }
                raw[len] = 0;
                boxnames = (string)raw;
                string []bsx = ((string)raw).split(";");
                int i = 0;
                foreach(var bs in bsx)
                {
                    switch(bs)
                    {
                        case "ARM":
                            arm_mask = (1 << i);
                            break;
                        case "ANGLE":
                            angle_mask = (1 << i);
                            break;
                        case "HORIZON":
                            horz_mask = (1 << i);
                            break;
                        case "GPS HOME":
                        case "NAV RTH":
                            rth_mask = (1 << i);
                            break;
                        case "GPS HOLD":
                        case "NAV POSHOLD":
                            ph_mask = (1 << i);
                            break;
                        case "NAV WP":
                        case "MISSION":
                            wp_mask = (1 << i);
                            break;
                    }
                    i++;
                }
                MWPLog.message("Masks arm %jx angle %jx horz %jx ph %jx rth %jx wp %jx\n",
                               arm_mask, angle_mask, horz_mask, ph_mask,
                               rth_mask, wp_mask);

                if(craft != null)
                    craft.set_icon(vi.mrtype);

                set_typlab();

                if(Logger.is_logging)
                {
                    string devnam = null;
                    if(msp.available)
                        devnam = dev_entry.get_active_text();
                    Logger.fcinfo(last_file,vi,capability,profile,
                                  boxnames,vname,devnam);
                }
                queue_cmd(MSP.Cmds.MISC,null,0);
                break;

            case MSP.Cmds.GPSSTATISTICS:
                LTM_XFRAME xf = LTM_XFRAME();
                deserialise_u16(raw, out gpsstats.last_message_dt);
                deserialise_u16(raw+2, out gpsstats.errors);
                deserialise_u16(raw+6, out gpsstats.timeouts);
                deserialise_u16(raw+10, out gpsstats.packet_count);
                deserialise_u16(raw+14, out gpsstats.hdop);
                deserialise_u16(raw+16, out gpsstats.eph);
                deserialise_u16(raw+18, out gpsstats.epv);
                rhdop = xf.hdop = gpsstats.hdop;
                gpsinfo.set_hdop(xf.hdop/100.0);
                if(Logger.is_logging)
                    Logger.ltm_xframe(xf);

                if(gps_status.visible)
                    gps_status.update(gpsstats);
                break;

            case MSP.Cmds.MISC:
                have_misc = true;
                vwarn1 = raw[19];
                need_mission = false;
                if((navcap & NAVCAPS.NAVCONFIG) == NAVCAPS.NAVCONFIG)
                    queue_cmd(MSP.Cmds.STATUS,null,0);
                else
                {
                    queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
                    queue_cmd(MSP.Cmds.ACTIVEBOXES,null,0);
                }
                break;

            case MSP.Cmds.ACTIVEBOXES:
                uint32 ab;
                deserialise_u32(raw, out ab);
                StringBuilder sb = new StringBuilder();
                sb.append_printf("Activeboxes %u %08x", len, ab);
                if(len > 4)
                {
                    deserialise_u32(raw+4, out ab);
                    sb.append_printf(" %08x", ab);
                }
                sb.append_c('\n');
                MWPLog.message(sb.str);
                if(vi.fc_vers >= FCVERS.hasTZ)
                {
                    MWPLog.message("Requesting common settings\n");
                    var s="nav_wp_safe_distance";
                    queue_cmd(MSP.Cmds.COMMON_SETTING, s, s.length+1);
                    s="inav_max_eph_epv";
                    queue_cmd(MSP.Cmds.COMMON_SETTING, s, s.length+1);
                    s="gps_min_sats";
                    queue_cmd(MSP.Cmds.COMMON_SETTING, s, s.length+1);
                }
                queue_cmd(msp_get_status,null,0);
                break;

            case MSP.Cmds.COMMON_SETTING:
                switch ((string)lastmsg.data)
                {
                    case "gps_min_sats":
                        msats = raw[0];
                        MWPLog.message("Received gps_min_sats %u\n", msats);
                        break;
                    case "nav_wp_safe_distance":
                        deserialise_u16(raw, out nav_wp_safe_distance);
                        MWPLog.message("Received (raw) nav_wp_safe_distance %u\n",
                                       nav_wp_safe_distance);
                        break;
                    case "inav_max_eph_epv":
                        uint32 ift;
                        deserialise_u32(raw, out ift);
                            // This stupidity is for Mint ...
                        uint32 *ipt = &ift;
                        float f = *((float *)ipt);
                        inav_max_eph_epv = (uint16)f;
                        MWPLog.message("Received (raw) inav_max_eph_epv %u\n",
                                       inav_max_eph_epv);
                        break;
                    default:
                        MWPLog.message("Unknown common setting %s\n",
                                       (string)lastmsg.data);
                        break;
                }
                break;

            case MSP.Cmds.STATUS:
            case MSP.Cmds.STATUS_EX:
            case MSP.Cmds.INAV_STATUS:
                handle_msp_status(raw, len);
                break;

            case MSP.Cmds.SENSOR_STATUS:
                for(var i = 0; i < 9; i++)
                    hwstatus[i] = raw[i];
                MWPLog.message("Sensor status %d\n", hwstatus[0]);
                if(hwstatus[0] == 0)
                    arm_warn.show();
                break;

            case MSP.Cmds.WP_GETINFO:
                var wpi = MSP_WP_GETINFO();
                uint8* rp = raw;
                rp++;
                wp_max = wpi.max_wp = *rp++;
                wpi.wps_valid = *rp++;
                wpi.wp_count = *rp;
                NavStatus.nm_pts = last_wp_pts = wpi.wp_count;
                MWPLog.message("WP_GETINFO: %u/%u/%u\n",
                               wpi.max_wp, wpi.wp_count, wpi.wps_valid);
                if((wpmgr.wp_flag & WPDL.GETINFO) != 0 && wpi.wps_valid == 0)
                {
                    mwp_warning_box("FC holds zero  WP (max %u)".printf(wpi.max_wp),
                                    Gtk.MessageType.ERROR, 10);
                    wpmgr.wp_flag &= ~WPDL.GETINFO;
                }
                else if (wpi.wp_count > 0 && wpi.wps_valid == 1 )
                {
                    string s = "Waypoints in FC\nMax: %u / Mission points: %u Valid: %s".printf(wpi.max_wp, wpi.wp_count, (wpi.wps_valid==1) ? "Yes" : "No");
                    mwp_warning_box(s, Gtk.MessageType.INFO, 2);
                    if(stslabel.get_text() == "No mission")
                    {
                        stslabel.set_text("%u WP valid in FC".printf(wpi.wp_count));
                        validatelab.set_text("✔"); // u+2714
                    }
                    if(ls.lastid == 0)
                    {
                        need_mission = true;
                    }
                    else
                    {
                        uint nwp = 0;
                        var wps = ls.to_wps(out downgrade);
                        foreach(var w in wps)
                        {
                            switch(w.action)
                            {
                                case MSP.Action.SET_POI:
                                case MSP.Action.SET_HEAD:
                                case MSP.Action.JUMP:
                                    break;
                                default:
                                    nwp++;
                                    break;
                            }
                        }
                        if(nwp != wpi.wp_count)
                            mwp_warning_box("WPs in FC (%d) != MWP mission (%u)".printf(wpi.wp_count, nwp), Gtk.MessageType.ERROR, 0);
                    }
                }
                break;

            case MSP.Cmds.NAV_STATUS:
            case MSP.Cmds.TN_FRAME:
            {
                MSP_NAV_STATUS ns = MSP_NAV_STATUS();
                uint8 flg = 0;
                uint8* rp = raw;
                ns.gps_mode = *rp++;

                if(ns.gps_mode == 15)
                {
                    if (nticks - last_crit > CRITINTVL)
                    {
                        bleet_sans_merci(Alert.GENERAL);
                        MWPLog.message("GPS Critial Failure!!!\n");
                        navstatus.gps_crit();
                        last_crit = nticks;
                    }
                }
                else
                    last_crit = 0;

                ns.nav_mode = *rp++;
                ns.action = *rp++;
                ns.wp_number = *rp++;
                ns.nav_error = *rp++;

                if(cmd == MSP.Cmds.NAV_STATUS)
                    deserialise_u16(rp, out ns.target_bearing);
                else
                {
                    flg = 1;
                    ns.target_bearing = *rp++;
                }
                navstatus.update(ns,item_visible(DOCKLETS.NAVSTATUS),flg);

                if((replayer & Player.BBOX) == 0 && (NavStatus.nm_pts > 0 && NavStatus.nm_pts != 255))
                {
                    if(ns.gps_mode == 3)
                    {
                        if ((conf.osd_mode & OSD.show_mission) != 0)
                        {
                            if (last_nmode != 3 || ns.wp_number != last_nwp)
                            {
                                ls.raise_wp(ns.wp_number);
                                string spt;
                                if(NavStatus.have_rth && ns.wp_number == NavStatus.nm_pts)
                                {
                                    spt = "<span size=\"x-small\">RTH</span>";
                                }
                                else
                                {
                                    StringBuilder sb = new StringBuilder(ns.wp_number.to_string());
                                    if(NavStatus.nm_pts > 0 && NavStatus.nm_pts != 255)
                                    {
                                        sb.append_printf("<span size=\"xx-small\">/%u</span>", NavStatus.nm_pts);
                                    }
                                    spt = sb.str;
                                }
                                map_show_wp(spt);
                            }
                        }
                        if ((conf.osd_mode & OSD.show_dist) != 0)
                        {
                            show_wp_distance(ns.wp_number);
                        }
                    }
                    else if (last_nmode == 3)
                    {
                        map_hide_wp();
                    }
                }
                last_nmode = ns.gps_mode;
                last_nwp= ns.wp_number;
            }
            break;

            case MSP.Cmds.NAV_POSHOLD:
                have_nc = true;
                MSP_NAV_POSHOLD poscfg = MSP_NAV_POSHOLD();
                uint8* rp = raw;
                poscfg.nav_user_control_mode = *rp++;
                rp = deserialise_u16(rp, out poscfg.nav_max_speed);
                rp = deserialise_u16(rp, out poscfg.nav_max_climb_rate);
                rp = deserialise_u16(rp, out poscfg.nav_manual_speed);
                rp = deserialise_u16(rp, out poscfg.nav_manual_climb_rate);
                poscfg.nav_mc_bank_angle = *rp++;
                poscfg.nav_use_midthr_for_althold = *rp++;
                rp = deserialise_u16(rp, out poscfg.nav_mc_hover_thr);
                ls.set_mission_speed(poscfg.nav_max_speed / 100.0);
                navconf.mr_update(poscfg);
                if (ls.lastid > 0)
                    ls.calc_mission();
                break;

            case MSP.Cmds.FW_CONFIG:
                have_nc = true;
                MSP_FW_CONFIG fw = MSP_FW_CONFIG();
                uint8* rp = raw;
                rp = deserialise_u16(rp, out fw.cruise_throttle);
                rp = deserialise_u16(rp, out fw.min_throttle);
                rp = deserialise_u16(rp, out fw.max_throttle);
                fw.max_bank_angle = *rp++;
                fw.max_climb_angle = *rp++;
                fw.max_dive_angle = *rp++;
                fw.pitch_to_throttle = *rp++;
                rp = deserialise_u16(rp, out fw.loiter_radius);
                navconf.fw_update(fw);
                break;

            case MSP.Cmds.NAV_CONFIG:
                have_nc = true;
                MSP_NAV_CONFIG nc = MSP_NAV_CONFIG();
                uint8* rp = raw;
                nc.flag1 = *rp++;
                nc.flag2 = *rp++;
                rp = deserialise_u16(rp, out nc.wp_radius);
                rp = deserialise_u16(rp, out nc.safe_wp_distance);
                rp = deserialise_u16(rp, out nc.nav_max_altitude);
                rp = deserialise_u16(rp, out nc.nav_speed_max);
                rp = deserialise_u16(rp, out nc.nav_speed_min);
                nc.crosstrack_gain = *rp++;
                rp = deserialise_u16(rp, out nc.nav_bank_max);
                rp = deserialise_u16(rp, out nc.rth_altitude);
                nc.land_speed = *rp++;
                rp = deserialise_u16(rp, out nc.fence);
                wp_max = nc.max_wp_number = *rp;
                navconf.mw_update(nc);
                ls.set_mission_speed(nc.nav_speed_max / 100.0);
                if (ls.lastid > 0)
                    ls.calc_mission();
                break;

            case MSP.Cmds.SET_NAV_CONFIG:
                MWPLog.message("RX set nav config\n");
                queue_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
                break;

            case MSP.Cmds.COMP_GPS:
                MSP_COMP_GPS cg = MSP_COMP_GPS();
                uint8* rp;
                rp = deserialise_u16(raw, out cg.range);
                rp = deserialise_i16(rp, out cg.direction);
                cg.update = *rp;
                navstatus.comp_gps(cg,item_visible(DOCKLETS.NAVSTATUS));
                break;

            case MSP.Cmds.ATTITUDE:
                MSP_ATTITUDE at = MSP_ATTITUDE();
                uint8* rp;
                rp = deserialise_i16(raw, out at.angx);
                rp = deserialise_i16(rp, out at.angy);
                deserialise_i16(rp, out at.heading);
                if (usemag || ((replayer & Player.MWP) == Player.MWP))
                {
                    mhead = at.heading;
                    if(mhead < 0)
                        mhead += 360;
                }
                navstatus.set_attitude(at,item_visible(DOCKLETS.NAVSTATUS));
                art_win.update(at.angx, at.angy, item_visible(DOCKLETS.ARTHOR));

                if((sensor & MSP.Sensors.GPS) == 0)
                    fbox.update(item_visible(DOCKLETS.FBOX));
                break;

            case MSP.Cmds.ALTITUDE:
                MSP_ALTITUDE al = MSP_ALTITUDE();
                uint8* rp;
                rp = deserialise_i32(raw, out al.estalt);
                deserialise_i16(rp, out al.vario);
                navstatus.set_altitude(al, item_visible(DOCKLETS.NAVSTATUS));
                break;

            case MSP.Cmds.ANALOG2:
                MSP_ANALOG an = MSP_ANALOG();
                uint16 v;
                uint32 pmah;
                deserialise_u16(raw+1, out v);
                deserialise_u16(raw+3, out an.amps);
                deserialise_u32(raw+9, out pmah);
                an.powermetersum = (uint16)pmah;
                deserialise_u16(raw+22, out an.rssi);
                an.vbat = v / 10;
                process_msp_analog(an);
                break;

            case MSP.Cmds.ANALOG:
                MSP_ANALOG an = MSP_ANALOG();
                an.vbat = raw[0];
                deserialise_u16(raw+1, out an.powermetersum);
                deserialise_i16(raw+3, out an.rssi);
                deserialise_i16(raw+5, out an.amps);
                process_msp_analog(an);
                break;

            case MSP.Cmds.RAW_GPS:
                MSP_RAW_GPS rg = MSP_RAW_GPS();
                uint8* rp = raw;
                rg.gps_fix = *rp++;
                if(rg.gps_fix != 0)
                {
                    if(replayer == Player.NONE)
                    {
                        if(inav)
                            rg.gps_fix++;
                    }
                    else
                        last_gps = nticks;
                }
                flash_gps();

                rg.gps_numsat = *rp++;
                rp = deserialise_i32(rp, out rg.gps_lat);
                rp = deserialise_i32(rp, out rg.gps_lon);
                rp = deserialise_i16(rp, out rg.gps_altitude);
                rp = deserialise_u16(rp, out rg.gps_speed);
                rp = deserialise_u16(rp, out rg.gps_ground_course);
                if(len == 18)
                {
                    deserialise_u16(rp, out rg.gps_hdop);
                    rhdop = rg.gps_hdop;
                    gpsinfo.set_hdop(rg.gps_hdop/100.0);
                }
                double ddm;
                gpsfix = (gpsinfo.update(rg, conf.dms, item_visible(DOCKLETS.GPS),
                                         out ddm) != 0);
                fbox.update(item_visible(DOCKLETS.FBOX));
                dbox.update(item_visible(DOCKLETS.DBOX));
                _nsats = rg.gps_numsat;

                if (gpsfix)
                {
                    if (vi.fc_api >= APIVERS.mspV2 && vi.fc_vers >= FCVERS.hasTZ)
                    {
                        if(rtcsecs == 0 && _nsats >= msats && replayer == Player.NONE)
                        {
                            MWPLog.message("Request RTC pos: %f %f sats %d hdop %.1f\n",
                                           GPSInfo.lat, GPSInfo.lon,
                                           _nsats, rhdop/100.0);
                            queue_cmd(MSP.Cmds.RTC,null, 0);
                        }
                    }

                    sat_coverage();
                    if(armed == 1)
                    {
                        var spd = (double)(rg.gps_speed/100.0);
                        update_odo(spd, ddm);
                        if(have_home == false && home_changed(GPSInfo.lat, GPSInfo.lon))
                        {
                            sflags |=  NavStatus.SPK.GPS;
                            want_special |= POSMODE.HOME;
                            navstatus.cg_on();
                        }
                    }

                    if(craft != null)
                    {
                        update_pos_info();
                    }
                    if(want_special != 0)
                        process_pos_states(GPSInfo.lat,GPSInfo.lon,
                                           rg.gps_altitude, "RAW GPS");
                }
                break;

            case MSP.Cmds.SET_WP:
                if(wpmgr.wps.length > 0)
                {
                    var no = wpmgr.wps[wpmgr.wpidx].wp_no;
                    request_wp(no);
                }
                else
                    wpmgr.wp_flag = WPDL.REPLAY;
                break;

            case MSP.Cmds.WP:
                handle_wp_processing(raw, len);
                break;

            case MSP.Cmds.WP_MISSION_SAVE:
                MWPLog.message("Confirmed mission save\n");
                break;

            case MSP.Cmds.EEPROM_WRITE:
                MWPLog.message("Wrote EEPROM\n");
                break;

            case MSP.Cmds.RADIO:
                if(!ignore_3dr)
                {
                    have_mspradio = true;
                    handle_radio(raw);
                }
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_RADIO:
                handle_radio(raw);
                break;

            case MSP.Cmds.TO_FRAME:
                LTM_OFRAME of = LTM_OFRAME();
                uint8* rp;
                rp = deserialise_i32(raw, out of.lat);
                rp = deserialise_i32(rp, out of.lon);
                of.fix = *(rp+5);
                double gflat = of.lat/10000000.0;
                double gflon = of.lon/10000000.0;

                if(home_changed(gflat, gflon))
                {
                    if(of.fix == 0)
                    {
                        no_ofix++;
                    }
                    else
                    {
                        navstatus.cg_on();
                        sflags |=  NavStatus.SPK.GPS;
                        want_special |= POSMODE.HOME;
                        process_pos_states(gflat, gflon, 0.0, "LTM OFrame");
                    }
                }
                if(Logger.is_logging)
                {
                    Logger.ltm_oframe(of);
                }
                break;

            case MSP.Cmds.TG_FRAME:
            {
                sflags |=  NavStatus.SPK.ELEV;
                LTM_GFRAME gf = LTM_GFRAME();
                uint8* rp;

                flash_gps();
                last_gps = nticks;

                rp = deserialise_i32(raw, out gf.lat);
                rp = deserialise_i32(rp, out gf.lon);

                gf.speed = *rp++;
                rp = deserialise_i32(rp, out gf.alt);
                gf.sats = *rp;
                init_craft_icon();
                MSP_ALTITUDE al = MSP_ALTITUDE();
                al.estalt = gf.alt;
                al.vario = 0;
                navstatus.set_altitude(al, item_visible(DOCKLETS.NAVSTATUS));

                double ddm;
                int fix = gpsinfo.update_ltm(gf, conf.dms, item_visible(DOCKLETS.GPS), rhdop, out ddm);
                _nsats = (gf.sats >> 2);

                if((_nsats == 0 && nsats != 0) || (nsats == 0 && _nsats != 0))
                {
                    nsats = _nsats;
                    navstatus.sats(_nsats, true);
                }

                if(fix > 0)
                {
                    sat_coverage();
                    if(armed != 0)
                    {
                        if(have_home)
                        {
                            if(_nsats >= msats)
                            {
                                if(pos_valid(GPSInfo.lat, GPSInfo.lon))
                                {
                                    double dist,cse;
                                    Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                                                home_pos.lat, home_pos.lon,
                                                out dist, out cse);
                                    if(dist < 256)
                                    {
                                        var cg = MSP_COMP_GPS();
                                        cg.range = (uint16)Math.lround(dist*1852);
                                        cg.direction = (int16)Math.lround(cse);
                                        navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
                                        update_odo((double)gf.speed, ddm);
                                    }
                                }
                            }
                        }
                        else
                        {
                            if(no_ofix == 10)
                            {
                                MWPLog.message("No home position yet\n");
                            }
                        }
                        if(magcheck && magtime > 0 && magdiff > 0)
                        {
                            int gcse = (int)GPSInfo.cse;
                            if(last_ltmf != 9 && last_ltmf != 15)
                            {
                                if(gf.speed > 3)
                                {
                                    if(get_heading_diff(gcse, mhead) > magdiff)
                                    {
                                        if(magdt == -1)
                                        {
                                            magdt = (int)duration;
//                                            MWPLog.message("set mag %d %d %d\n", mhead, (int)gcse, magdt);
                                        }
                                    }
                                    else if (magdt != -1)
                                    {
//                                        MWPLog.message("clear magdt %d %d %d\n", mhead, (int)gcse, magdt);
                                        magdt = -1;
                                    }
                                }
                                else
                                    magdt = -1;

                            }

                            if(magdt != -1 && ((int)duration - magdt) > magtime)
                            {
                                MWPLog.message(" ****** Heading anomaly detected %d %d %d\n",
                                               mhead, (int)gcse, magdt);
                                map_show_warning("HEADING ANOMALY");
                                bleet_sans_merci(Alert.RED);
                                magdt = -1;
                            }
                        }
                    }

                    if(craft != null && fix > 0 && _nsats >= msats)
                    {
                        update_pos_info();
                    }

                    if(want_special != 0)
                        process_pos_states(GPSInfo.lat, GPSInfo.lon, gf.alt/100.0, "GFrame");
                }
                fbox.update(item_visible(DOCKLETS.FBOX));
                dbox.update(item_visible(DOCKLETS.DBOX));
            }
            break;

            case MSP.Cmds.TX_FRAME:
                uint8* rp;
                LTM_XFRAME xf = LTM_XFRAME();
                rp = deserialise_u16(raw, out rhdop);
                xf.hdop = rhdop;
                xf.sensorok = *rp++;
                xf.ltm_x_count = *rp++;
                xf.disarm_reason = *rp;

                alert_broken_sensors(xf.sensorok);
                gpsinfo.set_hdop(rhdop/100.0);
                if(Logger.is_logging)
                    Logger.ltm_xframe(xf);

                if(armed == 0 && xf.disarm_reason != 0 &&
                   xf.disarm_reason < disarm_reason.length)
                    MWPLog.message("LTM Disarm (armed = %d) reason %s\n",
                                   armed, disarm_reason[xf.disarm_reason]);
                break;

            case MSP.Cmds.TA_FRAME:
            {
                LTM_AFRAME af = LTM_AFRAME();
                uint8* rp;
                rp = deserialise_i16(raw, out af.pitch);
                rp = deserialise_i16(rp, out af.roll);
                rp = deserialise_i16(rp, out af.heading);
                var h = af.heading;
                if(h < 0)
                    h += 360;
                mhead = h;
                navstatus.update_ltm_a(af, item_visible(DOCKLETS.NAVSTATUS));
                art_win.update(af.roll*10, af.pitch*10, item_visible(DOCKLETS.ARTHOR));
            }
            break;

            case MSP.Cmds.TS_FRAME:
            {
                LTM_SFRAME sf = LTM_SFRAME ();
                uint8* rp;
                rp = deserialise_u16(raw, out sf.vbat);
                rp = deserialise_u16(rp, out sf.vcurr);
                sf.rssi = *rp++;
                sf.airspeed = *rp++;
                sf.flags = *rp++;
                radstatus.update_ltm(sf,item_visible(DOCKLETS.RADIO));

                uint8 ltmflags = sf.flags >> 2;
                uint64 mwflags = 0;
                uint8 saf = sf.flags & 1;
                bool failsafe = ((sf.flags & 2)  == 2);

                if(xfailsafe != failsafe)
                {
                    if(failsafe)
                    {
                        MWPLog.message("Failsafe asserted %ds\n", duration);
                        map_show_warning("FAILSAFE");
                    }
                    else
                    {
                        MWPLog.message("Failsafe cleared %ds\n", duration);
                        map_hide_warning();
                    }
                    xfailsafe = failsafe;
                }

                if ((saf & 1) == 1)
                {
                    mwflags = arm_mask;
                    armed = 1;
                    dac = 0;
                }
                else
                {
                    dac++;
                    if(dac == 1 && armed != 0)
                    {
                        MWPLog.message("Assumed disarm from LTM %ds\n", duration);
                        mwflags = 0;
                        armed = 0;
                        init_have_home();
                        /* schedule the bubble machine again .. */
                        if(replayer == Player.NONE)
                        {
                            reset_poller();
                        }
                    }
                }
                if(ltmflags == 2)
                    mwflags |= angle_mask;
                if(ltmflags == 3)
                    mwflags |= horz_mask;
                if(ltmflags == 3)
                    mwflags |= arm_mask;
                if(ltmflags == 9)
                    mwflags |= ph_mask;
                if(ltmflags == 10)
                    mwflags |= wp_mask;
                if(ltmflags == 13 || ltmflags == 15)
                    mwflags |= rth_mask;
                else
                    mwflags = xbits; // don't know better

                armed_processing(mwflags,"ltm");
                var xws = want_special;
                if(ltmflags != last_ltmf)
                {
                    last_ltmf = ltmflags;
                    if(ltmflags == 9)
                        want_special |= POSMODE.PH;
                    else if(ltmflags == 10)
                    {
                        want_special |= POSMODE.WP;
                        if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
                            NavStatus.nm_pts = last_wp_pts;
                    }
                    else if(ltmflags == 13)
                        want_special |= POSMODE.RTH;
                    else if(ltmflags == 8)
                        want_special |= POSMODE.ALTH;
                    else if(ltmflags == 18)
                        want_special |= POSMODE.CRUISE;
                    else if(ltmflags != 15)
                    {
                        if(craft != null)
                            craft.set_normal();
                    }
                    var lmstr = MSP.ltm_mode(ltmflags);
                    MWPLog.message("New LTM Mode %s (%d) %d %ds %f %f %x %x\n",
                                   lmstr, ltmflags, armed, duration,
                                   xlat, xlon, xws, want_special);
                    fmodelab.set_label(lmstr);
                }
                if(want_special != 0 /* && have_home*/)
                    process_pos_states(xlat,xlon, 0, "SFrame");

                uint16 mah = sf.vcurr;
                uint16 ivbat = (sf.vbat + 50) / 100;
                var mahtm = GLib.get_monotonic_time ();
                    // for mwp replay, we either have analog or don't bother
                if ((replayer & Player.MWP) == Player.NONE)
                {
                    if ((replayer & Player.BBOX) == Player.BBOX
                        && curr.bbla > 0)
                    {
                        curr.ampsok = true;
                        curr.centiA = curr.bbla;
                        if (mah > curr.mah)
                            curr.mah = mah;
                        navstatus.current(curr, 2);
                            // already checked for odo with bbl amps
                    }
                    else if (mah > 0 && mah != 0xffff && curr.lmah > 0)
                    {
                        if (mah > curr.lmah)
                        {
                            var tdiff = (mahtm - curr.lmahtm);
                            var cdiff = mah - curr.lmah;
                                // should be time aware
                            if(cdiff < 100 || curr.lmahtm == 0)
                            {
                                curr.ampsok = true;
                                    // 100 * 1000 * 1000 * 3600 / 1000
                                    // centiA, microsecs, hours / milli AH
                                var iamps = (uint16)(cdiff * 3600000*100 / tdiff);
                                if (iamps >=  0 && tdiff > 200000)
                                {
                                    curr.centiA = iamps;
                                    curr.mah = mah;
                                    navstatus.current(curr, 2);
                                    if (curr.centiA > odo.amps)
                                    {
                                        MWPLog.message("set max amps %s %s (%s)\n",
                                                       odo.amps.to_string(),
                                                       curr.centiA.to_string(),
                                                       mah.to_string());
                                        odo.amps = curr.centiA;
                                    }
                                }
                            }
                        }
                        else if (curr.lmah - mah > 100)
                        {
                            MWPLog.message("Negative energy usage %u %u\n", curr.lmah, mah);
                        }
                    }
                }
                curr.lmahtm = mahtm;
                curr.lmah = mah;
                navstatus.update_ltm_s(sf, item_visible(DOCKLETS.NAVSTATUS));
                MSP_ANALOG an = MSP_ANALOG();
                an.vbat = (uint8)ivbat;
                an.powermetersum = (uint16)curr.mah;
                an.rssi = 1023*sf.rssi/254;
                an.amps = curr.centiA;
                process_msp_analog(an);
            }
            break;

            case MSP.Cmds.MAVLINK_MSG_ID_HEARTBEAT:
                Mav.MAVLINK_HEARTBEAT m = *(Mav.MAVLINK_HEARTBEAT*)raw;
                force_mav = false;
                if(mavc == 0 &&  msp.available)
                    send_mav_heartbeat();
                mavc++;
                mavc %= 64;

                if(craft == null)
                {
                    Mav.mav2mw(m.type);
                    init_craft_icon();
                }

                if ((m.base_mode & 128) == 128)
                    armed = 1;
                else
                    armed = 0;
                sensor = mavsensors;
                armed_processing(armed,"mav");

                if(Logger.is_logging)
                    Logger.mav_heartbeat(m);
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_SYS_STATUS:
                Mav.MAVLINK_SYS_STATUS m = *(Mav.MAVLINK_SYS_STATUS*)raw;
                if(sflags == 1)
                {
                    mavsensors = 1;
                    if((m.onboard_control_sensors_health & 0x8) == 0x8)
                    {
                        sflags |= NavStatus.SPK.BARO;
                        mavsensors |= MSP.Sensors.BARO;
                    }
                    if((m.onboard_control_sensors_health & 0x20) == 0x20)
                    {
                        sflags |= NavStatus.SPK.GPS;
                        mavsensors |= MSP.Sensors.GPS;
                    }
                    if((m.onboard_control_sensors_health & 0x4)== 0x4)
                    {
                        mavsensors |= MSP.Sensors.MAG;
                    }
                }
                set_bat_stat(m.voltage_battery/100);
                if(Logger.is_logging)
                    Logger.mav_sys_status(m);
                break;

            case MSP.Cmds.MAVLINK_MSG_GPS_GLOBAL_INT:
                break;

            case MSP.Cmds.MAVLINK_MSG_GPS_RAW_INT:
                Mav.MAVLINK_GPS_RAW_INT m = *(Mav.MAVLINK_GPS_RAW_INT*)raw;
                double ddm;
                var fix  = gpsinfo.update_mav_gps(m, conf.dms,
                                                  item_visible(DOCKLETS.GPS), out ddm);
                gpsfix = (fix > 1);
                _nsats = m.satellites_visible;

                if(gpsfix)
                {
                    if(armed == 1)
                    {
                        if(m.vel != 0xffff)
                        {
                            update_odo(m.vel/100.0, ddm);
                        }

                        if(have_home == false)
                        {
                            sflags |=  NavStatus.SPK.GPS;
                            navstatus.cg_on();
                        }
                        else
                        {
                            double dist,cse;
                            Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                                        home_pos.lat, home_pos.lon,
                                        out dist, out cse);
                            var cg = MSP_COMP_GPS();
                            cg.range = (uint16)Math.lround(dist*1852);
                            cg.direction = (int16)Math.lround(cse);
                            navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
                        }
                    }
                    if(craft != null)
                    {
                        update_pos_info();
                        if(want_special != 0)
                            process_pos_states(GPSInfo.lat, GPSInfo.lon,
                                               m.alt/1000.0, "MavGPS");
                    }
                }
                fbox.update(item_visible(DOCKLETS.FBOX));
                dbox.update(item_visible(DOCKLETS.DBOX));
                break;

            case MSP.Cmds.MAVLINK_MSG_ATTITUDE:
                Mav.MAVLINK_ATTITUDE m = *(Mav.MAVLINK_ATTITUDE*)raw;
                if(usemag)
                {
                    mhead = (int16)(m.yaw*RAD2DEG);
                    if(mhead < 0)
                        mhead += 360;
                }
                navstatus.set_mav_attitude(m,item_visible(DOCKLETS.NAVSTATUS));
                art_win.update((int16)(m.roll*57.29578*10), (int16)(m.pitch*57.29578*10),
                               item_visible(DOCKLETS.ARTHOR));
                break;

            case MSP.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW:
                for (var j = 0; j < mavposdef.length; j++)
                {
                    if(mavposdef[j].chan != 0)
                    {
                        var offset = mavposdef[j].chan+1;
                        uint16 val = *(((uint16*)raw)+offset);
                        if(val > mavposdef[j].minval && val < mavposdef[j].maxval)
                        {
                            if(mavposdef[j].set == 0)
                            {
                                if (mavposdef[j].ptype == Craft.Special.PH)
                                    want_special |= POSMODE.PH;
                                else if (mavposdef[j].ptype == Craft.Special.RTH)
                                    want_special |= POSMODE.RTH;
                            }
                            mavposdef[j].set = 1;
                        }
                        else
                        {
                            mavposdef[j].set = 0;
                        }
                    }
                }
                if(Logger.is_logging)
                {
                    Mav.MAVLINK_RC_CHANNELS m = *(Mav.MAVLINK_RC_CHANNELS*)raw;
                    Logger.mav_rc_channels(m);
                    radstatus.update_rssi(m.rssi,item_visible(DOCKLETS.RADIO));
                }
                break;

            case MSP.Cmds.MAVLINK_MSG_GPS_GLOBAL_ORIGIN:
                Mav. MAVLINK_GPS_GLOBAL_ORIGIN m = *(Mav.MAVLINK_GPS_GLOBAL_ORIGIN *)raw;
                var ilat  = m.latitude / 10000000.0;
                var ilon  = m.longitude / 10000000.0;

                if(want_special != 0)
                    process_pos_states(ilat, ilon, m.altitude / 1000.0, "MAvOrig");

                if(Logger.is_logging)
                {
                    Logger.mav_gps_global_origin(m);
                }
                break;

            case MSP.Cmds.MAVLINK_MSG_VFR_HUD:
                Mav.MAVLINK_VFR_HUD m = *(Mav.MAVLINK_VFR_HUD *)raw;
                mhead = (int16)m.heading;
                navstatus.set_mav_altitude(m, item_visible(DOCKLETS.NAVSTATUS));
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_RADIO_STATUS:
                break;
            case MSP.Cmds.REBOOT:
                MWPLog.message("Reboot scheduled\n");
                serial_doom(conbutton);
                Timeout.add(1000, () => {
                        if(!msp.available && !autocon)
                        {
                            MWPLog.message("Reconnecting\n");
                            connect_serial();
                        }
                        return Source.REMOVE;
                    });
                break;

            case MSP.Cmds.Tq_FRAME:
                uint16 val = *(((uint16*)raw));
                odo.time = val;
                duration = (time_t)val;
                break;

            case MSP.Cmds.Ta_FRAME:
                uint16 val = *(((uint16*)raw));
                curr.bbla = val;
                if (val > odo.amps)
                    odo.amps = val;
                break;

            case MSP.Cmds.Tx_FRAME:
                if (replayer != Player.NONE)
                {
                    if(raw[0] != 0)
                        MWPLog.message("BB Disarm %s (%u)\n",
                                       MSP.bb_disarm(raw[0]),
                                       raw[0]);
                    cleanup_replay();
                }
                break;

            case MSP.Cmds.SET_NAV_POSHOLD:
                queue_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
                queue_cmd(MSP.Cmds.NAV_POSHOLD, null,0);
                break;

            case MSP.Cmds.SET_FW_CONFIG:
                queue_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
                queue_cmd(MSP.Cmds.FW_CONFIG, null,0);
                break;

            case MSP.Cmds.WP_MISSION_LOAD:
                download_mission();
                break;

            case MSP.Cmds.SET_RTC:
                MWPLog.message("Set RTC ack\n");
                break;

            case MSP.Cmds.DEBUGMSG:
                MWPLog.message("DEBUG:%s\n", (string)raw);
                break;

            default:
                uint mcmd;
                string mtxt;
                if (cmd < MSP.Cmds.LTM_BASE)
                {
                    mcmd = cmd;
                    mtxt = "MSP";
                }
                else if (cmd >= MSP.Cmds.LTM_BASE && cmd < MSP.Cmds.MAV_BASE)
                {
                    mcmd = cmd - MSP.Cmds.LTM_BASE;
                    mtxt = "LTM";
                }
                else
                {
                    mcmd = cmd - MSP.Cmds.MAV_BASE;
                    mtxt = "MAVLink";
                }

                StringBuilder sb = new StringBuilder("** Unknown ");
                sb.printf("%s : %u / %x (%ubytes)", mtxt, mcmd, mcmd, len);
                if(len > 0 && conf.dump_unknown)
                {
                    sb.append(" [");
                    foreach(var r in raw[0:len])
                        sb.append_printf(" %02x", r);
                    sb.append(" ]");
                }
                sb.append_c('\n');

                MWPLog.message (sb.str);
                break;
        }


        if(mq.is_empty() && serstate == SERSTATE.POLLER)
        {
            if (requests.length > 0)
                tcycle = (tcycle + 1) % requests.length;
            if(tcycle == 0)
            {
                lastp.stop();
                var et = lastp.elapsed();
                telstats.tot = 0;
                acycle += (uint64)(et*1000);
                anvals++;
                msg_poller();
            }
            else
            {
                send_poll();
            }
        }
        run_queue();
    }

    private void set_typlab()
    {
        string s;

        if(vname == null || vname.length == 0)
            s = MSP.get_mrtype(vi.mrtype);
        else
        {
            s = "«%s»".printf(vname);
        }
        typlab.label = s;
    }

    private int get_heading_diff (int a, int b)
    {
        var d = int.max(a,b) - int.min(a,b);
        if(d > 180)
            d = 360 - d;
        return d;
    }

/*
    private void show_wp(MSP_WP w)
    {
        stderr.printf("no %d\n", w.wp_no);
        stderr.printf("action %d\n", w.action);
        stderr.printf("lat %d\n", w.lat);
        stderr.printf("lon %d\n", w.lon);
        stderr.printf("alt %u\n", w.altitude);
        stderr.printf("p1,2,3 %d %d %d\n", w.p1, w.p2, w.p3);
        stderr.printf("flag %x\n", w.flag);
    }
*/
    private bool home_changed(double lat, double lon)
    {
        bool ret=false;
        var d1 = home_pos.lat - lat;
        var d2 = home_pos.lon - lon;

        if(((Math.fabs(d1) > 1e-6) || Math.fabs(d2) > 1e-6))
        {
            if(have_home && (home_pos.lat != 0.0) && (home_pos.lon != 0.0))
            {
                double d,cse;
                Geo.csedist(lat, lon, home_pos.lat, home_pos.lon, out d, out cse);
                d*=1852.0;
                if(d > conf.max_home_delta)
                {
                    bleet_sans_merci(Alert.GENERAL);
                    navstatus.alert_home_moved();
                    MWPLog.message(
                        "Established home has jumped %.1fm [%f %f (ex %f %f)]",
                        d, lat, lon, home_pos.lat, home_pos.lon);
                }
            }
            home_pos.lat = lat;
            home_pos.lon = lon;
            have_home = true;
            ret = true;
        }
        return ret;
    }

    private void process_pos_states(double lat, double lon, double alt,
                                    string? reason=null)
    {
        if (lat == 0.0 && lon == 0.0)
        {
            want_special = 0;
            last_ltmf = 0xff;
            return;
        }

        if((armed != 0) && ((want_special & POSMODE.HOME) != 0))
        {
            have_home = true;
            want_special &= ~POSMODE.HOME;
            home_pos.lat = xlat = lat;
            home_pos.lon = xlon = lon;
            home_pos.alt = alt;
            markers.add_home_point(lat,lon,ls);
            init_craft_icon();
            if(craft != null)
            {
                if(nrings != 0)
                    markers.initiate_rings(view, lat,lon, nrings, ringint,
                                           conf.rcolstr);
                craft.special_wp(Craft.Special.HOME, lat, lon);
            }
            else
            {
                init_have_home();
            }

            if(chome)
                map_centre_on(lat,lon);

            StringBuilder sb = new StringBuilder ();
            if(reason != null)
            {
                sb.append(reason);
                sb.append_c(' ');
            }
            sb.append(have_home.to_string());
            MWPLog.message("Set home %f %f (%s)\n", lat, lon, sb.str);
        }

        if((want_special & POSMODE.PH) != 0)
        {
            want_special &= ~POSMODE.PH;
            MWPLog.message("Set poshold %f %f\n", lat, lon);
            ph_pos.lat = lat;
            ph_pos.lon = lon;
            ph_pos.alt = alt;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.PH, lat, lon);
        }
        if((want_special & POSMODE.RTH) != 0)
        {
            want_special &= ~POSMODE.RTH;
            rth_pos.lat = lat;
            rth_pos.lon = lon;
            rth_pos.alt = alt;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.RTH, lat, lon);
        }
        if((want_special & POSMODE.ALTH) != 0)
        {
            want_special &= ~POSMODE.ALTH;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.ALTH, lat, lon);
        }
        if((want_special & POSMODE.CRUISE) != 0)
        {
            want_special &= ~POSMODE.CRUISE;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.CRUISE, lat, lon);
        }
        if((want_special & POSMODE.WP) != 0)
        {
            want_special &= ~POSMODE.WP;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.WP, lat, lon);
            markers.update_ipos(ls, lat, lon);
        }
    }

    private void handle_radio(uint8[] raw)
    {
        MSP_RADIO r = MSP_RADIO();
        uint8 *rp;
        rp = deserialise_u16(raw, out r.rxerrors);
        rp = deserialise_u16(rp, out r.fixed_errors);
        r.localrssi = *rp++;
        r.remrssi = *rp++;
        r.txbuf = *rp++;
        r.noise = *rp++;
        r.remnoise = *rp;
        radstatus.update(r,item_visible(DOCKLETS.RADIO));
    }

    private void send_mav_heartbeat()
    {
        uint8 dummy[9]={0};
        msp.send_mav(0, dummy, 9);
    }

    private void report_bits(uint64 bits)
    {
        string mode = null;
        if((bits & angle_mask) == angle_mask)
        {
            mode = "Angle";
        }
        else if((bits & horz_mask) == horz_mask)
        {
            mode = "Horizon";
        }
        else if((bits & (ph_mask | rth_mask)) == 0)
        {
            mode = "Acro";
        }
        if(mode != null)
        {
            fmodelab.set_label(mode);
            navstatus.update_fmode(mode);
        }
    }

    private size_t serialise_wp(MSP_WP w, uint8[] tmp)
    {
        uint8* rp = tmp;
        *rp++ = w.wp_no;
        *rp++ = w.action;
        rp = serialise_i32(rp, w.lat);
        rp = serialise_i32(rp, w.lon);
        rp = serialise_u32(rp, w.altitude);
        rp = serialise_u16(rp, w.p1);
        rp = serialise_u16(rp, w.p2);
        rp = serialise_u16(rp, w.p3);
        *rp++ = w.flag;
        return (rp-&tmp[0]);
    }

    private void bleet_sans_merci(string sfn=Alert.RED)
    {
        StringBuilder sb = new StringBuilder();
        if(beep_disabled == false)
        {
            var fn = MWPUtils.find_conf_file(sfn);
            if(fn != null)
            {
                if(use_gst)
                {
                    Gst.Element play = Gst.ElementFactory.make ("playbin", "player");
                    File file = File.new_for_path (fn);
                    var uri = file.get_uri ();
                    play.set("uri", uri);
                    play.set("volume", 5.0);
                    play.set_state (Gst.State.PLAYING);
                }
                else
                {
                    sb.assign(conf.mediap);
                    sb.append_c(' ');
                    sb.append(fn);
                    try {
                        use_gst = !Process.spawn_command_line_async (sb.str);
                    } catch (SpawnError e) {
                        use_gst = true;
                    }
                }
            }
        }
        sb.assign("Alert: ");
        sb.append(sfn);
        if(sfn == Alert.SAT)
        {
            sb.append(" (");
            sb.append(nsats.to_string());
            sb.append_c(')');
        }
        sb.append_c('\n');
        MWPLog.message(sb.str);
    }

    private void init_battery(uint8 ivbat)
    {
        bat_annul();
        var ncells = ivbat / 37;
        for(var i = 0; i < vcol.levels.length; i++)
        {
            vcol.levels[i].limit = vcol.levels[i].cell*ncells;
            vcol.levels[i].reached = false;
        }
        vinit = true;
        vwarn1 = 0;
    }

    private void bat_annul()
    {
        curr = {false,0,0,0,0 ,0};
        for(var i = 0; i < MAXVSAMPLE; i++)
                vbsamples[i] = 0;
        nsampl = 0;
    }

    private void set_bat_stat(uint8 ivbat)
    {
        if(ivbat < 20)
        {
            update_bat_indicators(vcol.levels.length-1, 0.0f);
        }
        else
        {
            float  vf = ((float)ivbat)/10.0f;
            if (nsampl == MAXVSAMPLE)
            {
                for(var i = 1; i < MAXVSAMPLE; i++)
                    vbsamples[i-1] = vbsamples[i];
            }
            else
                nsampl += 1;

            vbsamples[nsampl-1] = vf;
            vf = 0;
            for(var i = 0; i < nsampl; i++)
                vf += vbsamples[i];
            vf /= nsampl;

            if(vinit == false)
                init_battery(ivbat);

            int icol = 0;
            foreach(var v in vcol.levels)
            {
                if(vf >= v.limit)
                    break;
                icol += 1;
            }

            update_bat_indicators(icol, vf);

            if(vcol.levels[icol].reached == false)
            {
                vcol.levels[icol].reached = true;
                if(vcol.levels[icol].audio != null)
                {
                    if(replayer == Player.NONE)
                        bleet_sans_merci(vcol.levels[icol].audio);
                    else
                        MWPLog.message("battery alarm %.1f\n", vf);
                }
            }
        }
    }

    private void update_bat_indicators(int icol, float vf)
    {
        string str;
        if(vcol.levels[icol].label == null)
        {
            str = "%.1fv".printf(vf);
        }
        else
            str = vcol.levels[icol].label;

        if(icol != licol)
            licol= icol;

        navstatus.volt_update(str,icol,vf,item_visible(DOCKLETS.VOLTAGE));
    }


    private void upload_mission(WPDL flag)
    {
        if(!msp.available)
        {
            if ((flag & WPDL.CALLBACK) != 0)
                upload_callback(0);
            return;
        }

        validatelab.set_text("");
        downgrade = 0;

        var wps = ls.to_wps(out downgrade, inav, Craft.is_fw(vi.mrtype));
        if(wps.length > wp_max)
        {
            if((flag & WPDL.CALLBACK) != 0)
                upload_callback(0);
            string str = "Number of waypoints (%d) exceeds max (%d)".printf(
                wps.length, wp_max);
            mwp_warning_box(str, Gtk.MessageType.ERROR, 60);
            return;
        }

        if(downgrade != 0)
        {
            string str = "WARNING\nmwp downgraded %u multiwii specific waypoint(s) to compatible iNav equivalent(s). Once the upload has completed, please check you're happy with the result.\n\nNote that iNav will treat a final bare WAYPOINT as POSHOLD UNLIMITED".printf(downgrade);
            mwp_warning_box(str, Gtk.MessageType.WARNING);
        }

        if(wps.length == 0)
        {
/**********
            if(inav)
            {
                if((flag & WPDL.CALLBACK) != 0)
                    upload_callback(0);
                mwp_warning_box("Cowardly refusal to upload an empty mission",
                                Gtk.MessageType.WARNING, 60);
                return;
            }
            else
***********/
            {
                MSP_WP w0 = MSP_WP();
                w0.wp_no = 1;
                w0.action =  MSP.Action.RTH;
                w0.lat = 0;
                w0.lon = 0;
                w0.altitude = 25;
                w0.p1 = 0;
                w0.p2 = w0.p3 = 0;
                w0.flag = 0xa5;
                wps += w0;
            }
        }

        serstate = SERSTATE.NORMAL;
        mq.clear();
        MWPCursor.set_busy_cursor(window);

        if(conf.recip_head)
        {
            for(var ix = 0 ; ix < wps.length; ix++)
            {
                if(wps[ix].action == MSP.Action.SET_HEAD && wps[ix].p1 != -1)
                {
                    wps[ix].p1 = (wps[ix].p1 + 180) % 360;
                }
            }
        }

        wpmgr.npts = (uint8)wps.length;
        wpmgr.wpidx = 0;
        wpmgr.wps = wps;
        wpmgr.wp_flag = flag;

        var timeo = 1500+(wps.length*1000);
        uint8 wtmp[64];
        var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
        queue_cmd(MSP.Cmds.SET_WP, wtmp, nb);
        start_wp_timer(timeo);
    }

    public void start_wp_timer(uint timeo, string reason="WP")
    {
        upltid = Timeout.add(timeo, () => {
                MWPCursor.set_normal_cursor(window);
                MWPLog.message("%s operation probably failed\n", reason);
                string wmsg = "%s operation timeout.\nThe upload has probably failed".printf(reason);
                mwp_warning_box(wmsg, Gtk.MessageType.ERROR);

                if((wpmgr.wp_flag & WPDL.CALLBACK) != 0)
                    upload_callback(-2);
                return Source.REMOVE;
            });
    }

    public void request_wp(uint8 wp)
    {
        uint8 buf[2];
        have_wp = false;
        buf[0] = wp;
        queue_cmd(MSP.Cmds.WP,buf,1);
    }

    private size_t serialise_nc (MSP_NAV_CONFIG nc, uint8[] tmp)
    {
        uint8* rp = tmp;

        *rp++ = nc.flag1;
        *rp++ = nc.flag2;

        rp = serialise_u16(rp, nc.wp_radius);
        rp = serialise_u16(rp, nc.safe_wp_distance);
        rp = serialise_u16(rp, nc.nav_max_altitude);
        rp = serialise_u16(rp, nc.nav_speed_max);
        rp = serialise_u16(rp, nc.nav_speed_min);
        *rp++ = nc.crosstrack_gain;
        rp = serialise_u16(rp, nc.nav_bank_max);
        rp = serialise_u16(rp, nc.rth_altitude);
        *rp++ = nc.land_speed;
        rp = serialise_u16(rp, nc.fence);
        *rp++ = nc.max_wp_number;
        return (rp-&tmp[0]);
    }

    private size_t serialise_pcfg (MSP_NAV_POSHOLD pcfg, uint8[] tmp)
    {
        uint8* rp = tmp;

        *rp++ = pcfg.nav_user_control_mode;
        rp = serialise_u16(rp, pcfg.nav_max_speed);
        rp = serialise_u16(rp, pcfg.nav_max_climb_rate);
        rp = serialise_u16(rp, pcfg.nav_manual_speed);
        rp = serialise_u16(rp, pcfg.nav_manual_climb_rate);
        *rp++ = pcfg.nav_mc_bank_angle;
        *rp++ = pcfg.nav_use_midthr_for_althold;
        rp = serialise_u16(rp, pcfg.nav_mc_hover_thr);
        return (rp-&tmp[0]);
    }

    private size_t serialise_fw (MSP_FW_CONFIG fw, uint8[] tmp)
    {
        uint8* rp = tmp;
        rp = serialise_u16(rp, fw.cruise_throttle);
        rp = serialise_u16(rp, fw.min_throttle);
        rp = serialise_u16(rp, fw.max_throttle);
        *rp++ = fw.max_bank_angle;
        *rp++ = fw.max_climb_angle;
        *rp++ = fw.max_dive_angle;
        *rp++ = fw.pitch_to_throttle;
        rp = serialise_u16(rp, fw.loiter_radius);
        return (rp-&tmp[0]);
    }

    private void mw_update_config(MSP_NAV_CONFIG nc)
    {
        have_nc = false;
        uint8 tmp[64];
        var nb = serialise_nc(nc, tmp);
        queue_cmd(MSP.Cmds.SET_NAV_CONFIG, tmp, nb);
        queue_cmd(MSP.Cmds.NAV_CONFIG,null,0);
    }

    private void mr_update_config(MSP_NAV_POSHOLD pcfg)
    {
        have_nc = false;
        uint8 tmp[64];
        var nb = serialise_pcfg(pcfg, tmp);
        queue_cmd(MSP.Cmds.SET_NAV_POSHOLD, tmp, nb);
    }

    private void fw_update_config(MSP_FW_CONFIG fw)
    {
        have_nc = false;
        uint8 tmp[64];
        var nb = serialise_fw(fw, tmp);
        queue_cmd(MSP.Cmds.SET_FW_CONFIG, tmp, nb);
    }

    private void queue_cmd(MSP.Cmds cmd, void* buf, size_t len)
    {
        if(((debug_flags & DEBUG_FLAGS.INIT) != DEBUG_FLAGS.NONE)
           && (serstate == SERSTATE.NORMAL))
            MWPLog.message("Init MSP %s (%u)\n", cmd.to_string(), cmd);

        if(replayer == Player.NONE)
        {
            uint8 *dt = (buf == null) ? null : Memory.dup(buf, (uint)len);
            if(msp.available == true)
            {
                var mi = MQI() {cmd = cmd, len = len, data = dt};
                mq.push_tail(mi);
            }
        }
    }

    private void start_audio(bool live = true)
    {
        if (spktid == 0)
        {
            if(audio_on)
            {
                string voice = null;
                switch(spapi)
                {
                    case 1:
                        voice = conf.evoice;
                        if (voice == "default")
                            voice = "en"; // thanks, espeak-ng
                        break;
                    case 2:
                        voice = conf.svoice;
                        break;
                    case 3:
                        voice = conf.fvoice;
                        break;
                    default:
                        voice = null;
                        break;
                }
                navstatus.logspeak_init(voice, (conf.uilang == "ev"), exvox);
                spktid = Timeout.add_seconds(conf.speakint, () => {
                        if(replay_paused == false)
                            navstatus.announce(sflags);
                        return Source.CONTINUE;
                    });
                if(live)
                {
                    gps_alert(0);
                    navstatus.announce(sflags);
                }
            }
        }
    }

    private void stop_audio()
    {
        if(spktid > 0)
        {
            remove_tid(ref spktid);
            navstatus.logspeak_close();
        }
    }

    private void remove_tid(ref uint tid)
    {
        if(tid > 0)
            Source.remove(tid);
        tid = 0;
    }

    private void  gen_serial_stats()
    {
        if(msp.available)
            telstats.s = msp.dump_stats();
        telstats.avg = (anvals > 0) ? (ulong)(acycle/anvals) : 0;
    }

    private void show_serial_stats()
    {
        gen_serial_stats();
        MWPLog.message("%.0fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s) to %d wait %d, avg poll loop %lu ms messages %s\n",
                       telstats.s.elapsed, telstats.s.rxbytes, telstats.s.txbytes,
                       telstats.s.rxrate, telstats.s.txrate,
                       telstats.toc, telstats.tot, telstats.avg ,
                       telstats.s.msgs.to_string());
    }

    private void serial_doom(Gtk.Button c)
    {
        MWPLog.message("Serial doom replay %d\n", replayer);
        map_hide_wp();
        if(replayer == Player.NONE)
        {
            arm_warn.hide();
            serstate = SERSTATE.NONE;
            sflags = 0;
            if (conf.audioarmed == true)
            {
                audio_cb.active = false;
            }
            show_serial_stats();
            if(rawlog == true)
            {
                msp.raw_logging(false);
            }

            gpsinfo.annul();
            navstatus.annul();
            fbox.annul();
            dbox.annul();
            gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};
            art_win.update(0, 0, item_visible(DOCKLETS.ARTHOR));
            set_bat_stat(0);
            nsats = 0;
            _nsats = 0;
            last_tm = 0;
            last_ga = 0;
            boxnames = null;
            msp.close();
            c.set_label("Connect");
            set_mission_menus(false);
            set_menu_state("navconfig", false);
            duration = -1;
            if(craft != null)
            {
                craft.remove_marker();
            }
            init_have_home();
            set_error_status(null);
            xsensor = 0;
            clear_sensor_array();
        }
        else
        {
            replayer = Player.NONE;
        }
        if(fwddev != null && fwddev.available)
            fwddev.close();

        set_replay_menus(true);
        reboot_status();
    }

    private void set_replay_menus(bool state)
    {
        const string [] ms = {"replay-log","load-log","replay-bb","load-bb"};
        if(x_replay_bbox_ltm_rb == false)
            state = false;

        foreach(var s in ms)
        {
            set_menu_state(s, state);
        }
    }

    private void set_mission_menus(bool state)
    {
        const string[] ms0 = {"store-mission","restore-mission","upload-mission","download-mission","navconfig", "mission-info"};
        foreach(var s in ms0)
            set_menu_state(s, state);
    }

    private void init_sstats()
    {
        if(telstats.s.msgs != 0)
            gen_serial_stats();
        anvals = acycle = 0;
        telstats = {};
            //c = telstats.tot = 0;
            //lstats.avg = 0;
        telemstatus.annul();
        radstatus.annul();
    }

    private void init_state()
    {
        map_hide_warning();
        xfailsafe = false;
        serstate = SERSTATE.NONE;
        have_api = have_vers = have_misc = have_status = have_wp = have_nc =
            have_fcv = have_fcvv = false;
        xbits = icount = api_cnt = 0;
        autocount = 0;
        nsats = 0;
        gpsinfo.annul();
        bat_annul();
        navstatus.reset();
        art_win.update(0, 0, item_visible(DOCKLETS.ARTHOR));
        vinit = false;
        set_bat_stat(0);
        gpscnt = 0;
        force_mav = false;
        want_special = 0;
        xsensor = 0;
        have_mspradio = false;
        clear_sensor_array();
        nticks = lastrx = lastok = 0;
        last_ltmf = 0xff;
        validatelab.set_text("");
        ls.set_mission_speed(conf.nav_speed);
        msats = SATS.MINSATS;
        curr = {false, 0, 0, 0};
    }

    private bool try_forwarder(out string fstr)
    {
        fstr = null;
        if(!fwddev.available)
        {
            if(fwddev.open_w(forward_device, 0, out fstr) == true)
            {
                fwddev.set_mode(MWSerial.Mode.SIM);
                MWPLog.message("set forwarder %s\n", forward_device);
            }
            else
            {
                MWPLog.message("Forwarder %s\n", fstr);
            }
        }
        return fwddev.available;
    }

    private void connect_serial()
    {
        map_hide_wp();
        if(msp.available)
        {
            serial_doom(conbutton);
            markers.remove_rings(view);
            verlab.label = verlab.tooltip_text = "";
            typlab.set_label("");
            statusbar.push(context_id, "");
        }
        else
        {
            var serdev = dev_entry.get_active_text();
            string estr;
            bool ostat;

            serstate = SERSTATE.NONE;
            if(serdev == "*SMARTPORT*")
            {
                ostat = msp.open_sport(sport_device, out estr);
                spi = {0};
            }
            else
                ostat = msp.open_w(serdev, conf.baudrate, out estr);

            if (ostat == true)
            {
                MWPLog.message("Try connect %s\n", serdev);
                xarm_flags=0xffff;
                lastrx = lastok = nticks;
                init_state();
                init_sstats();
                MWPLog.message("Connected %s\n", serdev);
                set_replay_menus(false);
                if(rawlog == true)
                {
                    msp.raw_logging(true);
                }
                conbutton.set_label("Disconnect");
                if(forward_device != null)
                {
                    string fstr;
                    if(try_forwarder(out fstr) == false)
                    {
                        uint8 retry = 0;
                        Timeout.add(500, () => {
                                if (!msp.available)
                                    return false;
                                bool ret = !try_forwarder(out fstr);
                                if(ret && retry++ == 5)
                                {
                                    mwp_warning_box(
                                        "Failed to open forwarding device: %s\n".printf(fstr),
                                        Gtk.MessageType.ERROR,10);
                                    ret = false;
                                }
                                return ret;
                            });
                    }
                }
                msp.setup_reader();
                MWPLog.message("Serial ready\n");
                if(nopoll == false && (serdev != "*SMARTPORT*"))
                {
                    serstate = SERSTATE.NORMAL;
                    queue_cmd(MSP.Cmds.IDENT,null,0);
                    run_queue();
                }
                else
                    serstate = SERSTATE.TELEM;
            }
            else
            {
                if (autocon == false || autocount == 0)
                {
                    mwp_warning_box("Unable to open serial device\n%s\nPlease verify you are a member of the owning group\nTypically \"dialout\" or \"uucp\"\n".printf(estr));
                }
                autocount = ((autocount + 1) % 4);
            }
            reboot_status();
        }
    }

    private void anim_cb(bool forced=false)
    {
        if(pos_is_centre)
        {
            if (map_moved() || forced)
            {
                poslabel.set_text(PosFormat.pos(ly,lx,conf.dms));
                if (follow == false && craft != null)
                {
                    double plat,plon;
                    craft.get_pos(out plat, out plon);
                    var bbox = view.get_bounding_box();
                    if (bbox.covers(plat, plon) == false)
                    {
                        craft.park();
                    }
                }
            }
        }
    }

    private void add_source_combo(string? defmap, MapSource []msources)
    {
        string[] map_names={};
        var combo  = builder.get_object ("combobox1") as Gtk.ComboBox;
        var map_source_factory = Champlain.MapSourceFactory.dup_default();

        var liststore = new Gtk.ListStore (MS_Column.N_COLUMNS, typeof (string), typeof (string));

        foreach (unowned MapSource s0 in msources)
        {
            s0.desc = new  MwpMapSource(
                s0.id,
                s0.name,
                s0.licence,
                s0.licence_uri,
                s0.min_zoom,
                s0.max_zoom,
                s0.tile_size,
                Champlain.MapProjection.MERCATOR,
                s0.uri_format);
            map_source_factory.register((Champlain.MapSourceDesc)s0.desc);
        }

        var sources =  map_source_factory.get_registered();
        int i = 0;
        int defval = 0;
        string? defsource = null;

        foreach (Champlain.MapSourceDesc s in sources)
        {
            var name = s.get_name();
            if(name.contains("OpenWeatherMap"))
                continue;

            TreeIter iter;
            liststore.append(out iter);
            var id = s.get_id();
            liststore.set (iter, MS_Column.ID, id);

            if(name.contains("OpenStreetMap"))
                name = name.replace("OpenStreetMap","OSM");

            liststore.set (iter, MS_Column.NAME, name);
            if (defmap != null && name == defmap)
            {
                defval = i;
                defsource = id;
            }
            i++;
            map_names += name;
        }

        prefs.set_maps(map_names, conf.defmap);

        combo.changed.connect (() => {
                GLib.Value val1;
                TreeIter iter;
                combo.get_active_iter (out iter);
                liststore.get_value (iter, 0, out val1);
                var source = map_source_factory.create_cached_source((string)val1);
                var zval = zoomer.adjustment.value;
                var cx = lx;
                var cy = ly;
                view.map_source = source;
                view.set_max_zoom_level(source.get_max_zoom_level());
                view.set_min_zoom_level(source.get_min_zoom_level());
                zoomer.set_range (source.get_min_zoom_level(),source.get_max_zoom_level());

/* Stop oob zooms messing up the map */
                if(!check_zoom_sanity(zval))
                    view.center_on(cy, cx);
            });

        combo.set_model(liststore);

        if(defsource == null)
        {
            defsource = sources.nth_data(0).get_id();
            print("Settings blank id %s\n", defsource);
            defval = 0;
        }
        var src = map_source_factory.create_cached_source(defsource);
        view.set_property("map-source", src);

        var cell = new Gtk.CellRendererText();
        combo.pack_start(cell, false);

        combo.add_attribute(cell, "text", 1);
        combo.set_active(defval);
   }

    private bool check_zoom_sanity(double zval)
    {
        var mmax = view.get_max_zoom_level();
        var mmin = view.get_min_zoom_level();
        var sane = true;
        if (zval > mmax)
        {
            sane= false;
            view.zoom_level = mmax;
        }
        if (zval < mmin)
        {
            sane = false;
            view.zoom_level = mmin;
        }
        zoomer.adjustment.value = view.zoom_level;
        return sane;
    }

    public Mission get_mission_data()
    {
        Mission m = ls.to_mission();
        ls.calc_mission_dist(out m.dist, out m.lt, out m.et);
        m.nspeed = ls.get_mission_speed();
        if (conf.compat_vers != null)
            m.version = conf.compat_vers;
        wp_resp = m.get_ways();
        return m;
    }

    public void on_file_save()
    {
        if (last_file == null)
        {
            on_file_save_as ();
        }
        else
        {
            var m = get_mission_data();
            XmlIO.to_xml_file(last_file, m);
            update_title_from_file(last_file);
        }
        Timeout.add_seconds(2, () => {
                get_mission_pix();
                return Source.REMOVE;
            });
    }

    private string get_cached_mission_image(string mfn)
    {
        var cached = GLib.Path.build_filename(Environment.get_user_cache_dir(),
                                              "mwp");
        try
        {
            var dir = File.new_for_path(cached);
            dir.make_directory_with_parents ();
        } catch {}

        string md5name = mfn;
        if(!mfn.has_suffix(".mission"))
        {
            var ld = mfn.last_index_of_char ('.');
            if(ld != -1)
            {
                StringBuilder s = new StringBuilder(mfn[0:ld]);
                s.append(".mission");
                md5name = s.str;
            }
        }

        var chk = Checksum.compute_for_string(ChecksumType.MD5, md5name);
        StringBuilder sb = new StringBuilder(chk);
        sb.append(".png");
        return GLib.Path.build_filename(cached,sb.str);
    }

    private void get_mission_pix()
    {
        if(last_file != null)
        {
            var path = get_cached_mission_image(last_file);
            var wdw = embed.get_window();
            var w = wdw.get_width();
            var h = wdw.get_height();
            Gdk.Pixbuf pixb = null;
            try
            {
                if(is_wayland)
                {
                    int x,y;
                    bool ok;
                    string ofn;
                    wdw.get_origin (out x, out y);
                    ScreenShot ss = Bus.get_proxy_sync (BusType.SESSION,
                                                 "org.gnome.Shell.Screenshot",
                                                 "/org/gnome/Shell/Screenshot");
                    ss.ScreenshotArea(x, y, w, h,
                                      false, path,
                                      out ok, out ofn);
                    var img = new Gtk.Image.from_file(ofn);
                    pixb = img.get_pixbuf();
                }
                else
                {
                    {
                        pixb = Gdk.pixbuf_get_from_window (wdw, 0, 0, w, h);
                    }
                }
                int dw,dh;
                if(w > h)
                {
                    dw = 256;
                    dh = 256* h / w;
                }
                else
                {
                    dh = 256;
                    dw = 256* w / h;
                }
                var spixb = pixb.scale_simple(dw, dh, Gdk.InterpType.BILINEAR);
                spixb.save(path, "png");
            }
            catch (Error e) {
                MWPLog.message ("save preview: %s\n", e.message);
            }
        }
    }

    private void save_mission_file(string fn)
    {
        StringBuilder sb;
        uint8 ftype=0;

        if(fn.has_suffix(".mission") || fn.has_suffix(".xml"))
            ftype = 'm';

        if(fn.has_suffix(".json"))
        {
            ftype = 'j';
        }

        if(ftype == 0)
        {
            sb = new StringBuilder(fn);
            if(conf.mission_file_type == "j")
            {
                ftype = 'j';
                sb.append(".json");
            }
            else
            {
                ftype = 'm';
                sb.append(".mission");
            }
            fn = sb.str;
        }

        var m = get_mission_data();
        if (ftype == 'm')
            XmlIO.to_xml_file(fn, m);
        else
            JsonIO.to_json_file(fn, m);
    }

    public Mission? open_mission_file(string fn)
    {
        Mission m=null;
        bool is_j = fn.has_suffix(".json");
        m =  (is_j) ? JsonIO.read_json_file(fn) : XmlIO.read_xml_file (fn);

        if(m != null && m.npoints > 0)
        {
            NavStatus.nm_pts = (uint8)m.npoints;
            wp_resp = m.get_ways();
            return m;
        }
        else
        {
            NavStatus.nm_pts = 255;
            NavStatus.have_rth = false;
            wp_resp ={};
            return null;
        }
    }

    private void on_file_save_as ()
    {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select a mission file", null, Gtk.FileChooserAction.SAVE,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Save",
            Gtk.ResponseType.ACCEPT);
        chooser.set_transient_for(window);
        chooser.select_multiple = false;
        Gtk.FileFilter filter = new Gtk.FileFilter ();
        if(conf.missionpath != null)
            chooser.set_current_folder (conf.missionpath);

        filter.set_filter_name ("Mission");
        filter.add_pattern ("*.mission");
        filter.add_pattern ("*.xml");
        filter.add_pattern ("*.json");
        chooser.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);

        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    last_file = chooser.get_filename ();
                    save_mission_file(last_file);
                    update_title_from_file(last_file);
                }
                chooser.close ();
            });
        chooser.show_all();
    }

    private void update_title_from_file(string fname)
    {
        var basename = GLib.Path.get_basename(fname);
        StringBuilder sb = new StringBuilder("mwp = ");
        sb.append(basename);
        window.title = sb.str;
    }

    private uint guess_appropriate_zoom(Champlain.BoundingBox bb)
    {
        uint z = 18;

/********************************
 * Using the champlain API requires centring the map first
            for(z = view.get_max_zoom_level();
                z >= view.get_min_zoom_level(); z--)
            {
                var bb = view.get_bounding_box_for_zoom_level(z);
                if(bb.top > ms.maxy && bb.bottom < ms.miny &&
                   bb.right > ms.maxx && bb.left < ms.minx)
                    break;
            }

**********************************/

            // **************************************
            // Formula from:
            // http://wiki.openstreetmap.org/wiki/Zoom_levels
            //

        if(window_h != -1 && window_w != -1)
        {
            double cse,m_width,m_height;
            const double erad = 6372.7982; // earth radius
            const double ecirc = erad*Math.PI*2.0; // circumference
            const double rad = 0.017453292; // deg to rad
            double cx,cy;
            bb.get_center (out cy, out cx);
            Geo.csedist(cy, bb.left, cy, bb.right, out m_width, out cse);
            Geo.csedist(bb.bottom, cx, bb.top, cx, out m_height, out cse);
            m_width = m_width * 1852;
            m_height = m_height * 1852;
            for(z = view.get_max_zoom_level();
                z >= view.get_min_zoom_level(); z--)
            {
                double s = 1000 * ecirc * Math.cos(cy * rad) / (Math.pow(2,(z+8)));
                if(s*window_w > m_width && s*window_h > m_height)
                    break;
            }
        }
        return z;
    }

    private void load_file(string fname, bool warn=true)
    {
        var ms = open_mission_file(fname);
        if(ms != null)
        {
            instantiate_mission(ms);
            last_file = fname;
            update_title_from_file(fname);
            MWPLog.message("loaded %s\n", fname);
        }
        else
            if (warn)
                mwp_warning_box("Failed to open file");
    }

    private void set_view_zoom(uint z)
    {
        var mmax = view.get_max_zoom_level();
        var mmin = view.get_min_zoom_level();

        if (z < mmin)
            z = mmin;

        if (z > mmax)
            z = mmax;
        view.zoom_level = z;
    }

    private void instantiate_mission(Mission ms)
    {
        if(armed == 0 && craft != null)
        {
            markers.remove_rings(view);
            craft.init_trail();
        }
        validatelab.set_text("");
        map_centre_on(ms.cy, ms.cx);
        ms.dump();
        ls.import_mission(ms, (conf.rth_autoland &&
                               Craft.is_mr(vi.mrtype)));

        NavStatus.have_rth = ls.have_rth;
        if(ms.zoom == 0)
            ms.zoom = guess_appropriate_zoom(bb_from_mission(ms));

        set_view_zoom(ms.zoom);
        markers.add_list_store(ls);

        if(have_home)
            markers.add_home_point(home_pos.lat,home_pos.lon,ls);
        need_preview = true;
    }

    private Champlain.BoundingBox bb_from_mission(Mission ms)
    {
        Champlain.BoundingBox bb = new Champlain.BoundingBox();
        bb.top = ms.maxy;
        bb.bottom = ms.miny;
        bb.right =  ms.maxx;
        bb.left = ms.minx;
        return bb;
    }

    public void mwp_warning_box(string warnmsg,
                                 Gtk.MessageType klass=Gtk.MessageType.WARNING,
                                 int timeout = 0)
    {
        var msg = new Gtk.MessageDialog.with_markup (window,
                                                     0,
                                                     klass,
                                                     Gtk.ButtonsType.OK,
                                                     warnmsg);
        if(timeout > 0 && permawarn == false)
        {
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

    private void on_file_open()
    {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select a mission file", null, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);
        chooser.select_multiple = false;
        if(conf.missionpath != null)
            chooser.set_current_folder (conf.missionpath);

        chooser.set_transient_for(window);
        Gtk.FileFilter filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Mission");
        filter.add_pattern ("*.mission");
        filter.add_pattern ("*.xml");
        filter.add_pattern ("*.json");
        chooser.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);

        var prebox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        var preview = new Gtk.Image();
        var plabel = new Gtk.Label (null);
        prebox.pack_start (preview, false, false, 1);
        prebox.pack_start (plabel, false, false, 1);

        chooser.set_preview_widget(prebox);
        chooser.update_preview.connect (() => {
                string uri = chooser.get_preview_uri ();
                Gdk.Pixbuf pixbuf = null;
                if (uri != null && uri.has_prefix ("file://") == true)
                {
                    var fn = uri.substring (7);
                    if(!FileUtils.test (fn, FileTest.IS_DIR))
                    {
                        var m = open_mission_file(fn);
                        if(m != null)
                        {
                            var sb = new StringBuilder();
                            sb.append_printf("Points: %u\n", m.npoints);
                            sb.append_printf("Distance: %.1fm\n", m.dist);
                            sb.append_printf("Flight time %02d:%02d\n", m.et/60, m.et%60 );
                            if(m.lt != -1)
                                sb.append_printf("Loiter time: %ds\n", m.lt);
                            if(m.nspeed == 0 && m.dist > 0 && m.et > 0)
                                m.nspeed = m.dist / (m.et - 3*m.npoints);
                            sb.append_printf("Speed: %.1f m/s\n", m.nspeed);
                            if(m.maxalt != 0x80000000)
                                sb.append_printf("Max altitude: %dm\n", m.maxalt);
                            plabel.set_text(sb.str);
                        }
                        else
                            plabel.set_text("");

                        var ifn = get_cached_mission_image(fn);
                        try
                        {
                            pixbuf = new Gdk.Pixbuf.from_file_at_scale (ifn, 256,
                                                                       256, true);
                        }
                        catch {
                            if (FileUtils.test (fn, FileTest.EXISTS))
                                pixbuf = FlatEarth.getpixbuf(fn, 256, 256);
                        }
                    }
                }

                if(pixbuf != null)
                {
                    preview.set_from_pixbuf(pixbuf);
                    prebox.show_all ();
                }
                else
                    prebox.hide ();
            });

        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT)
                {
                    var fn = chooser.get_filename ();
                    chooser.close ();
                    load_file(fn);
                }
                else
                    chooser.close ();
            });
        chooser.show_all();
    }

    private void replay_log(bool delay=true)
    {
        if(thr != null)
        {
            robj.stop();
        }
        else
        {
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select a log file", null, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);
            chooser.select_multiple = false;
            chooser.set_transient_for(window);
            Gtk.FileFilter filter = new Gtk.FileFilter ();
            filter.set_filter_name ("Log");
            filter.add_pattern ("*.log");
            chooser.add_filter (filter);
            if(conf.logpath != null)
                chooser.set_current_folder (conf.logpath);

            filter = new Gtk.FileFilter ();
            filter.set_filter_name ("All Files");
            filter.add_pattern ("*");
            chooser.add_filter (filter);

            chooser.response.connect((res) => {
                    if ( res == Gtk.ResponseType.ACCEPT) {
                        var fn = chooser.get_filename ();
                        chooser.close ();
                        usemag = force_mag;
                        run_replay(fn, delay, Player.MWP);
                    }
                    else
                        chooser.close ();
                });
            chooser.show_all();
        }
    }

    private void cleanup_replay()
    {
        magcheck = (magtime > 0 && magdiff > 0);
        MWPLog.message("============== Replay complete ====================\n");
        if ((replayer & Player.MWP) == Player.MWP)
        {
            if(thr != null)
            {
                thr.join();
                thr = null;
            }
        }
        set_replay_menus(true);
        set_menu_state("stop-replay", false);
        Posix.close(playfd[0]);
        Posix.close(playfd[1]);
        if (conf.audioarmed == true)
            audio_cb.active = false;
        conf.logarmed = xlog;
        conf.audioarmed = xaudio;
        duration = -1;
        armtime = 0;
        armed_spinner.stop();
        armed_spinner.hide();
        conbutton.sensitive = true;
        armed = larmed = 0;
        replay_paused = false;
        window.title = "mwp";
    }

    private void run_replay(string fn, bool delay, Player rtype,
                            int idx=0, int btype=0, uint8 force_gps=0)
    {
        xlog = conf.logarmed;
        xaudio = conf.audioarmed;

        playfd = new int[2];
        var sr = MwpPipe.pipe(playfd);

        if(sr == 0)
        {
            replay_paused = false;
            MWPLog.message("Replay \"%s\" log %s model %d\n",
                           (rtype == 2) ? "bbox" : "mwp",
                           fn, btype);
            if(craft != null)
                craft.park();

            init_have_home();
            conf.logarmed = false;
            if(delay == false)
                conf.audioarmed = false;

            if(msp.available)
                serial_doom(conbutton);

            init_state();
            serstate = SERSTATE.NONE;
            conbutton.sensitive = false;
            update_title_from_file(fn);
            replayer = rtype;
            if(delay == false)
                replayer |= Player.FAST_MASK;

            msp.open_fd(playfd[0],-1, true);
            set_replay_menus(false);
            set_menu_state("stop-replay", true);
            magcheck = delay;
            switch(replayer)
            {
                case Player.MWP:
                case Player.MWP_FAST:
                    check_mission(fn);
                    robj = new ReplayThread();
                    thr = robj.run(playfd[1], fn, delay);
                    break;
                case Player.BBOX:
                case Player.BBOX_FAST:
                    bb_runner.find_bbox_box(fn, idx);
                    spawn_bbox_task(fn, idx, btype, delay, force_gps);
                    break;
            }
        }
    }

    private void check_mission(string missionlog)
    {
        bool done = false;
        string mfn = null;

        var dis = FileStream.open(missionlog,"r");
        if (dis != null)
        {
            var parser = new Json.Parser ();
            string line = null;
            while (!done && (line = dis.read_line ()) != null) {
                try
                {
                    parser.load_from_data (line);
                    var obj = parser.get_root ().get_object ();
                    var typ = obj.get_string_member("type");
                    switch(typ)
                    {
                        case "init":
                            if(obj.has_member("mission"))
                                mfn =  obj.get_string_member("mission");
                            done = true;
                            break;
                        case "armed":
                            done = true;
                            break;
                    }
                } catch {
                    done = true;
                }
            }
        }
        if(mfn != null)
        {
            hard_display_reset(true);
            load_file(mfn, false);
        }
        else
            hard_display_reset(false);
    }

    private void spawn_bbox_task(string fn, int index, int btype,
                                 bool delay, uint8 force_gps)
    {
        string [] args = {"replay_bbox_ltm.rb",
                          "--fd", "%d".printf(playfd[1]),
                          "-i", "%d".printf(index),
                          "-t", "%d".printf(btype),
                          "--decoder", conf.blackbox_decode};
        if(delay == false)
            args += "-f";
        if((force_gps & 1) == 1)
            args += "-g";
        if((force_gps & 2) == 2)
            args += "-G";

        args += fn;
        args += null;

        MWPLog.message("%s\n", string.joinv(" ",args));
        try {
            Process.spawn_async_with_pipes (null, args, null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.LEAVE_DESCRIPTORS_OPEN |
                                            SpawnFlags.STDOUT_TO_DEV_NULL |
                                            SpawnFlags.STDERR_TO_DEV_NULL |
                                            SpawnFlags.DO_NOT_REAP_CHILD,
                                            (() => {
                                                for(var i = 3; i < 512; i++)
                                                {
                                                    if(i != playfd[1])
                                                        Posix.close(i);
                                                }
                                            }),
                                            out child_pid,
                                            null, null, null);
            ChildWatch.add (child_pid, (pid, status) => {
                    MWPLog.message("Close child pid %u, %u\n",
                                   pid, Process.exit_status(status));
                    Process.close_pid (pid);
                    cleanup_replay();
                });
        } catch (SpawnError e) {
            MWPLog.message("spawnerror: %s\n", e.message);
        }
    }

    private void replay_bbox (bool delay, string? fn = null)
    {
        if((replayer & Player.BBOX) == Player.BBOX)
        {
            Posix.kill(child_pid, MwpSignals.Signal.TERM);
        }
        else
        {
            var id = bb_runner.run(fn);
            if(id == 1001)
            {
                string bblog;
                int index;
                int btype;
                uint8 force_gps = 0;

                bb_runner.get_result(out bblog, out index, out btype,
                                     out force_gps);
                run_replay(bblog, delay, Player.BBOX, index, btype, force_gps);
            }
        }
    }

    private void stop_replayer()
    {
        if((replayer & Player.BBOX) == Player.BBOX)
            Posix.kill(child_pid, MwpSignals.Signal.TERM);

        if((replayer & Player.MWP) == Player.MWP && thr != null)
            robj.stop();
        replay_paused = false;
    }

    private void download_mission()
    {
        wp_resp= {};
        wpmgr.wp_flag = WPDL.REPLACE;
        serstate = SERSTATE.NORMAL;
        mq.clear();
        start_wp_timer(30*1000);
        request_wp(1);
    }

    public static void xchild()
    {
        JsonMapDef.killall();
        if(Logger.is_logging)
            Logger.stop();
    }

    private static string read_cmd_opts()
    {
        var sb = new StringBuilder ();
        var fn = MWPUtils.find_conf_file("cmdopts");
        if(fn != null)
        {
            var file = File.new_for_path(fn);
            try {
                var dis = new DataInputStream(file.read());
                string line;
                while ((line = dis.read_line (null)) != null)
                {
                    if(line.strip().length > 0 &&
                       !line.has_prefix("#") &&
                       !line.has_prefix(";"))
                    {
                        sb.append(line);
                        sb.append_c(' ');
                    }
                }
            } catch (Error e) {
                error ("%s", e.message);
            }
        }
        return sb.str;
    }

    private static string? read_env_args()
    {
        var s1 = read_cmd_opts();
        var s2 = Environment.get_variable("MWP_ARGS");
        var sb = new StringBuilder();
        if(s1.length > 0)
           sb.append(s1);
        if(s2 != null)
            sb.append(s2);
        if(sb.len > 0)
        {
            sb.prepend("mwp ");
            return sb.str;

        }
        else
            return null;
    }

    private static string? check_env_args(OptionContext opt, string?s)
    {
        if(s != null)
        {
            string []m;
            try
            {
                Shell.parse_argv(s, out m);
                unowned string? []om = m;
                opt.parse(ref om);
            } catch {}
            return s[4:s.length];
        }
        return null;
    }

    public static int main (string[] args)
    {
        var lk = new Locker();
        int lkres;

        if((lkres = lk.lock()) == 0)
        {
            string defargs = read_env_args();
            is_wayland = (Environment.get_variable("WAYLAND_DISPLAY") != null);
            if (is_wayland)
            {
                if(defargs != null && defargs.contains("--wayland"))
                    use_wayland = true;
                else
                {
                    foreach (var a in args)
                        if (a == "--wayland")
                            use_wayland = true;
                }

                if(use_wayland)
                    MWPLog.message("Wayland enabled, if you experience problems, remove the --wayland option\n");
                else
                {
                    MWPLog.message("Using Xwayland for safety:)\n");
                    Gdk.set_allowed_backends("x11");
                }
            }

            if (GtkClutter.init (ref args) != InitError.SUCCESS)
                return 1;

            var sb = new StringBuilder("mwp ");
            sb.append(MwpVers.build);
            sb.append_c(' ');
            sb.append(MwpVers.id);
            var verstr = sb.str;
            string fixedopts=null;

            var opt = new OptionContext("");
            try {
                opt.set_summary("  %s".printf(verstr));
                opt.set_help_enabled(true);
                opt.add_main_entries(options, null);
                fixedopts = check_env_args(opt, defargs);
                opt.parse(ref args);
            } catch (OptionError e) {
                stderr.printf("Error: %s\n", e.message);
                stderr.printf("Run '%s --help' to see a full list of available "+
                              "options\n", args[0]);
                return 1;
            }

            if(show_vers)
            {
                stderr.printf("%s\n", verstr);
            }
            else if(Posix.geteuid() == 0 && asroot == false)
            {
                print("You should not run this application as root\n");
            }
            else
            {
                MWPLog.message("mwp startup version: %s\n", verstr);
                MWPLog.message("on %s\n", Logger.get_host_info());
                if(fixedopts != null)
                    MWPLog.message("default options: %s\n", fixedopts);
                Gst.init (ref args);
                MwpLibC.atexit(MWPlanner.xchild);
                var app = new MWPlanner();
                app.run ();
                app.cleanup();
            }
            lk.unlock();
        }
        else
            print("Application is already running\n");

        return lkres;
    }
}
