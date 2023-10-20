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

public delegate void ActionFunc ();

public class MWP : Gtk.Application {
    private const uint MAXVSAMPLE=12;
    private const uint8 MAV_BEAT_MASK=7; // mask, some power of 2 - 1
	public const string MWPID="org.stronnag.mwp";
    public Builder builder;
    public Gtk.ApplicationWindow window=null;
	private MwpSplash? splash;
    private int window_h = -1;
    private int window_w = -1;
    public  Champlain.View view;
    public MWPMarkers markers;
    private string last_file;
    private ListBox ls;
    private Gtk.SpinButton zoomer;
    private Gtk.ComboBoxText actmission;
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
    private static bool beep_disabled = false;

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
    private OTXDialog otx_runner;
    private RAWDialog raw_runner;
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
    private VarioBox vabox;
    public RadarView radarv;
    private WPMGR wpmgr;
    private MissionItem[] wp_resp;
    private string boxnames = null;
    private int autocount = 0;
    private uint8 last_wp_pts =0;

    private FollowMeDialog fmdlg;
    private FollowMePoint fmpt;

    private Mission? []lastmission;
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
    private time_t phtim;

    private uint8 armed = 0;
    private uint8 dac = 0;
    private bool gpsfix;
    private bool ltm_force_sats = false;

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
#if MQTT
    private MwpMQTT mqtt;
#endif
    private bool mqtt_available = false;
    private uint64 acycle;
    private uint64 anvals;
    private uint64 xbits = 0;
    private uint8 api_cnt;
    private uint8 icount = 0;
    private bool usemag = false;
    private int16 mhead;

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

    public MwpDockHelper mwpdh;

        /* for jump protection */
    private double xlon = 0;
    private double xlat = 0;

    private bool inav = false;
    private bool sensor_alm = false;
    private uint8 xs_state = 0;

    private uint16  rhdop = 10000;
    private uint gpsintvl = 0;
    private bool telem = false;
    private uint8 wp_max = 0;

    private uint16 nav_wp_safe_distance = 10000;
    private uint16 inav_max_eph_epv = 1000;
    private uint16 nav_rth_home_offset_distance = 0;

    private bool need_mission = false;
    private Clutter.Text clutextr;
    private Clutter.Text clutextg;
    private Clutter.Text clutextd;
    private bool map_clean;
    private VCol vcol;
    private Odostats odo;
    private OdoView odoview;
    private uint8 last_nmode = 0;
    private uint8 last_nwp = 0;
    private int wpdist = 0;
    private uint8 msats;
    private MapSize mapsize;

    private string? vname = null;

    private uchar hwstatus[9];
    private ModelMap mmap;

    private GPSStatus gps_status;
    private MSP_GPSSTATISTICS gpsstats;
    private int magdt = -1;
    private int magtime=0;
    private int magdiff=0;
    private bool magcheck;
    private uint8 say_state = 0;

    private bool x_replay_bbox_ltm_rb;
    private bool x_kmz;
    private bool x_otxlog;
    private bool x_aplog;
    private bool x_fl2ltm;
    private bool x_rawreplay;
    public bool x_plot_elevations_rb {get; private set; default= false;}

    private Array<KmlOverlay> kmls;
    private FakeOffsets fakeoff;

    public DevManager devman;
    public PowerState pstate;
    private bool seenMSP = false;

    private SafeHomeDialog safehomed;
    private uint8 last_safehome = 0;
    private uint8 safeindex = 0;
    private bool is_shutdown = false;
    private MwpNotify? dtnotify = null;
	private Gtk.ComboBoxText dev_protoc;
	private Gtk.ComboBoxText viddev_c;
	public List<GstMonitor.VideoDev?>viddevs;
	private V4L2_dialog vid_dialog;
	private struct BBVideoList {
		VideoPlayer vp;
		int64 timer;
		bool vauto;
	}
	private BBVideoList? bbvlist;
	private  bool bbl_delay = true;

	private struct RadarDev {
		MWSerial dev;
		string name;
	}
	private RadarDev[] radardevs;

    private TelemTracker ttrk;

    private uint radartid = -1;
	private Sticks.StickWindow sticks;
	private bool sticks_ok = false;

	public struct MQI {
        MSP.Cmds cmd;
        size_t len;
        uint8 *data;
    }

    private MQI lastmsg;
    private Queue<MQI?> mq;

    private enum APIVERS {
        mspV2 = 0x0200,
        mixer = 0x0202,
    }

    public enum FCVERS {
        hasMoreWP = 0x010400,
        hasEEPROM = 0x010600,
        hasTZ = 0x010704,
        hasRCDATA = 0x010800,
        hasV2STATUS = 0x010801,
        hasJUMP = 0x020500,
        hasPOI = 0x020600,
        hasPHTIME = 0x020500,
        hasLAND = 0x020500,
        hasSAFEAPI = 0x020700,
        hasMONORTH = 0x020600,
        hasABSALT = 0x030000,
        hasWP_V4 = 0x040000,
        hasWP1m = 0x060000,
    }

    public enum WPS {
        isINAV = (1<<0),
        isFW = (1<<1),
        hasJUMP = (1<<2),
        hasPHT = (1<<3),
        hasLAND = (1<<4),
        hasPOI = (1<<5),
    }

    public enum SERSTATE {
        NONE=0,
        NORMAL,
        POLLER,
		SET_WP,
        TELEM = 128,
        TELEM_SP,
    }

    public enum DEBUG_FLAGS {
        NONE=0,
        WP = (1 << 0),
        INIT = (1 << 1),
        MSP = (1 << 2),
        ADHOC = (1 << 3),
        RADAR= (1 << 4),
        OTXSTDERR = (1 << 5),
		SERIAL = (1 << 6),
		VIDEO = (1 << 7),
		GCSLOC = (1 << 8),
    }

    private enum SAT_FLAGS {
        NONE=0,
        NEEDED = 1,
        URGENT = 2,
        BEEP = 4
    }

    private enum Player {
        NONE = 0,
        MWP = 1,
        BBOX = 2,
        OTX = 4,
        FL2LTM = 8,
        RAW = 16,
        FAST_MASK = 128,
        MWP_FAST = MWP |FAST_MASK,
        BBOX_FAST = BBOX|FAST_MASK,
        OTX_FAST = OTX|FAST_MASK,
        FL2_FAST = FL2LTM|FAST_MASK,
        RAW_FAST = RAW|FAST_MASK,
    }

	public struct Position {
        double lat;
        double lon;
        double alt;
    }

    private enum OSD {
        show_mission = 1,
        show_dist = 2
    }


    private static bool have_home;
    private static Position home_pos;
    private Position rth_pos;
    private Position ph_pos;
    private Position wp0;

    private uint64 ph_mask=0;
    private uint64 arm_mask=0;
    private uint64 rth_mask=0;
    private uint64 angle_mask=0;
    private uint64 horz_mask=0;
    private uint64 wp_mask=0;
    private uint64 cr_mask=0;
    private uint64 fs_mask=0;

    private uint no_ofix = 0;

    private TelemStats telstats;
    private LayMan lman;

    public SList<RadarPlot?> radar_plot;

    public enum NAVCAPS {
        NONE=0,
        WAYPOINTS=1,
        NAVSTATUS=2,
        NAVCONFIG=4,
        INAV_MR=8,
        INAV_FW=16
    }

    private NAVCAPS navcap;

    private enum DOCKLETS {
        MISSION=0,
        GPS = 1,
        NAVSTATUS = 2,
        VOLTAGE = 3,
        RADIO = 4,
        TELEMETRY = 5,
        ARTHOR = 6,
        FBOX = 7,
        DBOX = 8,
        VBOX = 9,
        NUMBER = 10
    }

    private enum MS_Column {
        ID,
        NAME,
        N_COLUMNS
    }

    private enum WPDL {
        IDLE=0,
        DOWNLOAD = (1<<0),
        REPLACE = (1<<1),
        POLL = (1<<2),
        REPLAY = (1<<3),
        SAVE_EEPROM = (1<<4),
        GETINFO = (1<<5),
        CALLBACK = (1<<6),
        CANCEL = (1<<7),
		SET_ACTIVE = (1<<8),
		SAVE_ACTIVE = (1<<9),
		RESET_POLLER = (1<<10),
		KICK_DL = (1<<11),
        FOLLOW_ME = (1 << 12),
    }

    private struct WPMGR {
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

    private enum POSMODE {
        HOME = 1,
        PH = 2,
        RTH = 4,
        WP = 8,
        ALTH = 16,
        CRUISE = 32,
		UNDEF = 64, // emergency maybe
    }

        // ./src/main/fc/runtime_config.h
    private enum ARMFLAGS {
        ARMED                                           = (1 << 2), // 4
        WAS_EVER_ARMED                                  = (1 << 3), // 8
        ARMING_DISABLED_FAILSAFE_SYSTEM                 = (1 << 7), // 80
        ARMING_DISABLED_NOT_LEVEL                       = (1 << 8), // 100
        ARMING_DISABLED_SENSORS_CALIBRATING             = (1 << 9), // 200
        ARMING_DISABLED_SYSTEM_OVERLOADED               = (1 << 10), // 400
        ARMING_DISABLED_NAVIGATION_UNSAFE               = (1 << 11), // 800
        ARMING_DISABLED_COMPASS_NOT_CALIBRATED          = (1 << 12), // 1000
        ARMING_DISABLED_ACCELEROMETER_NOT_CALIBRATED    = (1 << 13), // 2000
        ARMING_DISABLED_ARM_SWITCH                      = (1 << 14), // 4000
        ARMING_DISABLED_HARDWARE_FAILURE                = (1 << 15), // 8000
            // Alas, not reported by STATUS_EX
        ARMING_DISABLED_BOXFAILSAFE                     = (1 << 16), // 10000
        ARMING_DISABLED_BOXKILLSWITCH                   = (1 << 17), // 20000
        ARMING_DISABLED_RC_LINK                         = (1 << 18), // 40000
        ARMING_DISABLED_THROTTLE                        = (1 << 19), // 80000
        ARMING_DISABLED_CLI                             = (1 << 20), // 100000
        ARMING_DISABLED_CMS_MENU                        = (1 << 21), // 200000
        ARMING_DISABLED_OSD_MENU                        = (1 << 22), // 400000
        ARMING_DISABLED_ROLLPITCH_NOT_CENTERED          = (1 << 23), // 800000
        ARMING_DISABLED_SERVO_AUTOTRIM                  = (1 << 24), // 1000000
        ARMING_DISABLED_OOM                             = (1 << 25), // 2000000
        ARMING_DISABLED_INVALID_SETTING                 = (1 << 26), // 4000000
        ARMING_DISABLED_PWM_OUTPUT                      = (1 << 27), // 8000000
        ARMING_DISABLED_PREARM                          = (1 << 28), // 10000000
        ARMING_DISABLED_DSHOTBEEPER                     = (1 << 29), // 20000000
        ARMING_DISABLED_LANDING_DETECTED                = (1 << 30), // 40000000
        ARMING_DISABLED_OTHER                           = (1 << 31), // 80000000
    }

    private string? [] arm_fails = {
        null, null, "Armed",null, /*"Ever Armed"*/ null,null,null,
        "Failsafe", "Not level","Calibrating","Overload",
        "Navigation unsafe", "Compass cal", "Acc cal", "Arm switch", "Hardware failure",
        "Box failsafe", "Box killswitch", "RC Link", "Throttle", "CLI",
        "CMS Menu", "OSD Menu", "Roll/Pitch", "Servo Autotrim", "Out of memory",
        "Settings", "PWM Output", "PreArm", "DSHOTBeeper", "Landed", "Other"
    };

    private enum SENSOR_STATES {
        None = 0,
        OK = 1,
        UNAVAILABLE = 2,
        UNHEALTHY = 3
    }

    private string [] health_states = {
        "None", "OK", "Unavailable", "Unhealthy"
    };

    private string[] sensor_names = {
        "Gyro", "Accelerometer", "Compass", "Barometer",
        "GPS", "RangeFinder", "Pitot", "OpticalFlow"
    };

    private string [] disarm_reason = {
        "None", "Timeout", "Sticks", "Switch_3d", "Switch",
        "Killswitch", "Failsafe", "Navigation", "Landing" };

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
    private const uint RADARINTVL=(10000/TIMINTVL);

	private const uint MAXMULTI = 9;

    private enum SATS {
        MINSATS = 6
    }

    private enum FWDS {
        NONE=0,
        LTM=1,
        minLTM=2,
        minMAV=3,
        ALL=4
    }

    private const uint NVARIO=2;
    private struct varios {
        uint idx;
        int alts[2];
        uint ticks[2];
    }

    private const double RAD2DEG = 57.29578;

    private varios Varios;
    private Timer lastp;
    public uint nticks = 0;
    private uint lastdbus = 0;
    private uint lastm = 0;
    private uint lastrx = 0;
    private uint last_ga = 0;
    private uint last_gps = 0;
    private uint last_crit = 0;
    private uint last_tm = 0;
    private uint lastok = 0;
    private uint last_an = 0;
    private int nrings = 0;
    private double ringint = 0;
    private bool replay_paused;
    private CurrData curr;
    private VersInfo vi;

    private MwpServer mss=null;
    private uint8 spapi =  0;
    private uint inhibit_cookie = 0;

    public const string[] SPEAKERS =  {"none", "espeak","speechd","flite","external"};
    public enum SPEAKER_API {
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

    private string xlib;
    private bool is_wayland = false;
    private bool xnopoll = false;

        /* Options parsing */
    private bool permawarn = false;
    private string mission;
    private string kmlfile;
    private string serial;
    private bool autocon;
    private bool mkcon = false;
    private bool ignore_sz = false;
    private bool nopoll = false;
    public bool rawlog = false;
    private bool no_trail = false;
    private bool no_max = false;
    private bool force_mag = false;
    private bool force_nc = false;
    private bool force4 = false;
    private bool chome = false;
    private string mwoptstr;
    private string llstr=null;
    private string layfile=null;
    private bool asroot = false;
    private bool legacy_unused;
    public string exstr;
    private bool offline = false;
    private string rfile = null;
    private string bfile = null;
	private string otxfile = null;
    private string forward_device = null;
    private string[]? radar_device = null;
    private int dmrtype=0;
    private DEBUG_FLAGS debug_flags = 0;
    private bool set_fs;
    private int stack_size = 0;
    private int mod_points = 0;
    private bool ignore_3dr = false;
    private string? exvox = null;
    private string rrstr;
    private bool nofsmenu = false;
    private bool relaxed = false;
    private bool ready;
	private Mission [] msx;  // v4 multis
	private int mdx = 0;
	private int imdx = 0;
	private bool ms_from_loader; // loading from file

    private MeasureLayer? mlayer = null;

	public static string? user_args;

	public enum HomeType {
		NONE,
		ORIGIN,
		PLAN
	}

	private struct DOCKDEF {
		DOCKLETS tag;
		string id;
		string name;
		string icon;
		string stock;
	}

	// Old style definitions for older compilers (buster, cygwin)
	private DOCKDEF[] ddefs = {
		DOCKDEF(){tag=DOCKLETS.MISSION, id="Mission", name="Mission Editor", icon="open-menu-symbolic", stock="gtk-properties"},
		DOCKDEF(){tag=DOCKLETS.GPS, id="GPS", name="GPS Info", icon="view-refresh-symbolic", stock="gtk-refresh"},
		DOCKDEF(){tag=DOCKLETS.NAVSTATUS, id="Status", name="NAV Status", icon="dialog-information-symbolic", stock="gtk-info"},
		DOCKDEF(){tag=DOCKLETS.VOLTAGE, id="Volts", name="Battery Monitor", icon="battery-symbolic", stock="gtk-dialog-warning"},
		DOCKDEF(){tag=DOCKLETS.RADIO, id="Radio", name="Radio Status", 	icon="network-wireless-symbolic", stock="gtk-network"},
		DOCKDEF(){tag=DOCKLETS.TELEMETRY, id="Telemetry", name="Telemetry", icon="network-cellular-symbolic", stock="gtk-disconnect"},
		DOCKDEF(){tag=DOCKLETS.ARTHOR, id="Horizons", name="Artificial Horizon", icon="object-flip-horizontal-symbolic", stock="gtk-justify-fill"},
		DOCKDEF(){tag=DOCKLETS.FBOX, id="FlightView",name="FlightView", icon="edit-find-symbolic", stock="gtk-find"},
		DOCKDEF(){tag=DOCKLETS.DBOX, id="DirectionView", name="DirectionView", icon="view-fullscreen-symbolic", stock="gtk-fullscreen"},
		DOCKDEF(){tag=DOCKLETS.VBOX, id="VarioView", name="VarioView", icon="object-flip-vertical-symbolic", stock="gtk-go-up"}
	};

    const OptionEntry[] options = {
        { "mission", 'm', 0, OptionArg.STRING, null, "Mission file", "file-name"},
        { "serial-device", 's', 0, OptionArg.STRING, null, "Serial device", "device_name"},
        { "device", 'd', 0, OptionArg.STRING, null, "Serial device", "device-name"},
        { "flight-controller", 'f', 0, OptionArg.STRING, null, "mw|mwnav|bf|cf", "fc-name"},
        { "connect", 'c', 0, OptionArg.NONE, null, "connect to first device (does not set auto flag)", null},
        { "auto-connect", 'a', 0, OptionArg.NONE, null, "auto-connect to first device (sets auto flag)", null},
        { "no-poll", 'N', 0, OptionArg.NONE, null, "don't poll for nav info", null},
        { "no-trail", 'T', 0, OptionArg.NONE, null, "don't display GPS trail", null},
        { "raw-log", 'r', 0, OptionArg.NONE, null, "log raw serial data to file", null},
        { "ignore-sizing", 0, 0, OptionArg.NONE, null, "ignore minimum size constraint", null},
        { "full-screen", 0, 0, OptionArg.NONE, null, "open full screen", null},
        { "ignore-rotation", 0, 0, OptionArg.NONE, null, "legacy unused", null},
        { "dont-maximise", 0, 0, OptionArg.NONE, null, "don't maximise the window", null},
        { "force-mag", 0, 0, OptionArg.NONE, null, "force mag for vehicle direction", null},
        { "force-nav", 0, 0, OptionArg.NONE, null, "force nav capaable", null},
        { "layout", 'l', 0, OptionArg.STRING, null, "Layout name", null},
        { "force-type", 't', 0, OptionArg.INT, null, "Model type", "type-code_no"},
        { "force4", '4', 0, OptionArg.NONE, null, "Force ipv4", null},
        { "ignore-3dr", '3', 0, OptionArg.NONE, null, "Ignore 3DR RSSI info", null},
        { "centre-on-home", 'H', 0, OptionArg.NONE, null, "Centre on home", null},
        { "debug-flags", 0, 0, OptionArg.INT, null, "Debug flags (mask)", null},
        { "replay-mwp", 'p', 0, OptionArg.STRING, null, "replay mwp log file", "file-name"},
        { "replay-bbox", 'b', 0, OptionArg.STRING, null, "replay bbox log file", "file-name"},
        { "centre", 0, 0, OptionArg.STRING, null, "Centre position (lat lon or named place)", "position"},
        { "offline", 0, 0, OptionArg.NONE, null, "force offline proxy mode", null},
        { "n-points", 'S', 0, OptionArg.INT, null, "Number of points shown in GPS trail", "N"},
        { "mod-points", 'M', 0, OptionArg.INT, null, "Modulo points to show in GPS trail", "N"},

        { "rings", 0, 0, OptionArg.STRING, null, "Range rings (number, interval(m)), e.g. --rings 10,20", "number,interval"},
        { "voice-command", 0, 0, OptionArg.STRING, null, "External speech command", "command string"},
        { "version", 'v', 0, OptionArg.NONE, null, "show version", null},
        { "build-id", 0, 0, OptionArg.NONE, null, "show build id", null},
        { "really-really-run-as-root", 0, 0, OptionArg.NONE, null, "no reason to ever use this", null},
        { "forward-to", 0, 0, OptionArg.STRING, null, "forward telemetry to", "device-name"},
        { "radar-device", 0, 0, OptionArg.STRING_ARRAY, null, "dedicated inav radar device", "device-name"},
        {"perma-warn", 0, 0, OptionArg.NONE, null, "info dialogues never time out", null},
        {"fsmenu", 0, 0, OptionArg.NONE, null, "use a menu bar in full screen (vice a menu button)", null},
        { "kmlfile", 'k', 0, OptionArg.STRING, null, "KML file", "file-name"},
        {"relaxed-msp", 0, 0, OptionArg.NONE, null, "don't check MSP direction flag", null},
        {null}
    };

	public static bool any_home(out uint8 type, out double hlat, out double hlon) {
		bool res = true;
		if(have_home) {
			type = HomeType.ORIGIN;
			hlat = home_pos.lat;
			hlon = home_pos.lon;
		} else if (FakeHome.has_loc) {
			type = HomeType.PLAN;
			hlat = FakeHome.xlat;
			hlon = FakeHome.xlon;
		} else {
			res = false;
			type = HomeType.NONE;
			hlat = hlon = 0.0;
		}
		return res;
	}

    void show_startup() {
		builder = new Builder ();
        string[]ts={"mwp.ui", "menubar.ui", "mwpsc.ui"};
        foreach(var fnm in ts) {
            var fn = MWPUtils.find_conf_file(fnm);
            if (fn == null) {
                MWPLog.message ("No UI definition file\n");
                quit();
            } else {
                try {
                    builder.add_from_file (fn);
                } catch (Error e) {
                    MWPLog.message ("Builder: %s\n", e.message);
                    quit();
                }
            }
        }
        builder.connect_signals (null);

		MWPLog.message("%s\n", MWP.user_args);
		MWP.user_args = null;
        var sb = new StringBuilder("mwp ");
        var s_0 = MwpVers.get_build();
        var s_1 = MwpVers.get_id();
		string vendor=null;
		string renderer=null;

		MwpGL.glinfo(out vendor, out renderer);
        var rsb = new StringBuilder("GL: ");
		if (vendor == null)
			rsb.append("Unknown");
		else
			rsb.append(vendor);
		rsb.append(" / ");
		if (renderer == null)
			rsb.append("Unsupported");
		else
			rsb.append(renderer);

		sb.append(s_0);
        sb.append_c(' ');
        sb.append(s_1);
        var verstr = sb.str;
        xlib = "Wayland";
        is_wayland = (Environment.get_variable("WAYLAND_DISPLAY") != null);
        if(!is_wayland) {
            xlib="Xlib";
		} else {
			var window_type = Gdk.DisplayManager.get().default_display.get_type();
			if (window_type.name() ==  "GdkX11Display") {
				xlib = "XWayland";
				is_wayland = false;
			}
		}
        string[] dms = {
            "XDG_SESSION_DESKTOP", "DESKTOP_SESSION", "XDG_CURRENT_DESKTOP"
        };
        string dmstr = null;
        foreach (var dx in dms)  {
                dmstr = Environment.get_variable(dx);
                if (dmstr != null)
                    break;
            }
        if (dmstr == null) {
            dmstr = "Unknown DE";
        }

        MWPLog.message("buildinfo: %s\n", MwpVers.get_build_host());
        MWPLog.message("toolinfo: %s\n", MwpVers.get_build_compiler());
        MWPLog.message("version: %s\n", verstr);
        string os=null;
        MWPLog.message("%s\n", Logger.get_host_info(out os));
		MWPLog.message("WM: %s / %s\n", xlib, dmstr);
		MWPLog.message("%s\n", rsb.str);
        var vstr = check_virtual(os);
        if(vstr == null || vstr.length == 0)
            vstr = "none";
        MWPLog.message("hypervisor: %s\n", vstr);
    }

    public MWP (string? s)  {
        Object(application_id: MWPID, flags: ApplicationFlags.HANDLES_COMMAND_LINE);
        var v = check_env_args(s);
        set_opts_from_dict(v);
        add_main_option_entries(options);
        handle_local_options.connect(do_handle_local_options);
        activate.connect(handle_activate);
    }

    private int _command_line (ApplicationCommandLine command_line) {
		string[] args = command_line.get_arguments ();
		foreach (var a in args[1:args.length]) {
			guess_content_type(a);
		}
		var o = command_line.get_options_dict();
        set_opts_from_dict(o);
        activate();
        return 0;
    }

    public override int command_line (ApplicationCommandLine command_line) {
		this.hold ();
 		int res = _command_line (command_line);
		this.release ();
		return res;
    }

    private int do_handle_local_options(VariantDict o) {
            // return 0 to stop here ..
        if (o.contains("version")) {
            stdout.printf("%s\n", MwpVers.get_id());
            return 0;
        }

        if (o.contains("build-id")) {
            stdout.printf("%s\n", MwpVers.get_build());
            return 0;
        }
        return -1;
    }

    private void set_opts_from_dict(VariantDict o) {
        o.lookup("mission", "s", ref mission);
        o.lookup("kmlfile", "s", ref kmlfile);
        o.lookup("replay-mwp", "s", ref rfile);
        o.lookup("replay-bbox", "s", ref bfile);

        if(!ready) {
            o.lookup("serial-device", "s", ref serial);
            o.lookup("device", "s", ref serial);
            o.lookup("flight-controller", "s", ref mwoptstr);
            o.lookup("connect", "b", ref mkcon);
            o.lookup("auto-connect", "b", ref autocon);
            o.lookup("no-poll", "b", ref nopoll);
            o.lookup("no-trail", "b", ref no_trail);
            o.lookup("raw-log", "b", ref rawlog);
            o.lookup("ignore-sizing", "b", ref ignore_sz);
            o.lookup("full-screen", "b", ref set_fs);
            o.lookup("ignore-rotation", "b", ref legacy_unused);
            o.lookup("dont-maximise", "b", ref no_max);
            o.lookup("force-mag", "b", ref force_mag);
            o.lookup("force-nav", "b", ref force_nc);
            o.lookup("layout", "s", ref layfile);
            o.lookup("force-type", "i", ref dmrtype);
            o.lookup("force4", "b", ref force4);
            o.lookup("ignore-3dr", "b", ref ignore_3dr);
            o.lookup("centre-on-home", "b", ref chome);
            o.lookup("debug-flags", "i", ref debug_flags);
            o.lookup("centre", "s", ref llstr);
            o.lookup("offline", "b", ref offline);
            o.lookup("n-points", "i", ref stack_size);
            o.lookup("mod-points", "i", ref mod_points);
            o.lookup("rings", "s", ref rrstr);
            o.lookup("voice-command", "s", ref exvox);
            o.lookup("really-really-run-as-root", "b", ref asroot);
            o.lookup("forward-to", "s", ref forward_device);
			if (o.contains("radar-device")) {
				var ox = o.lookup_value("radar-device", VariantType.STRING_ARRAY);
				var rds = ox.dup_strv();
				foreach(var rd in rds) {
					radar_device += rd;
				}
			}
            o.lookup("perma-warn", "b", ref permawarn);
            o.lookup("fsmenu", "b", ref nofsmenu);
            o.lookup("relaxed-msp", "b", ref relaxed);
        }
    }

    void show_dock_id (DOCKLETS id, bool iconify=false) {
        print("show dock %u, icon %s closed %s, iconified %s\n",
              id, iconify.to_string(),
              dockitem[id].is_closed().to_string(),
              dockitem[id].is_iconified().to_string()
              );
        if(dockitem[id].is_closed() && !dockitem[id].is_iconified()) {
            dockitem[id].show();
            if(iconify)
                dockitem[id].iconify_item();
        }
        update_dockmenu(id);
    }

    bool item_visible(DOCKLETS id) {
        return !dockitem[id].is_closed();
    }

    private void set_dock_menu_status() {
        for(var id = DOCKLETS.MISSION; id < DOCKLETS.NUMBER; id += (DOCKLETS)1) {
            update_dockmenu(id);
            if(id == DOCKLETS.FBOX &&
               !dockitem[id].is_closed () && !dockitem[id].is_iconified()) {
                    Idle.add(() => {
                            fbox.check_size();
                            fbox.update(true);
                            return Source.REMOVE;
                        });
            }
        }
    }

    private void update_dockmenu(DOCKLETS id) {
        var res = (dockitem[id].is_closed () == dockitem[id].is_iconified());
        set_menu_state(dockmenus[id], !res);
    }

    public void cleanup_t() {
        cleanup(true);
    }
    public void cleanup_f() {
        cleanup(false);
    }

    private void on_file_opent() {
        on_file_open(true);
    }

    private void on_file_openf() {
        on_file_open(false);
    }

    private void cleanup(bool is_clean) {
		is_shutdown = true;
        if(is_clean) {
            conf.save_floating (mwpdh.floating);
            lman.save_config();
        }

        if(msp.available)
            msp.close();
#if MQTT
        if (mqtt.available)
            mqtt_available = mqtt.mdisconnect();
#endif
		foreach (var r in radardevs) {
			if(r.dev != null && r.dev.available)
				r.dev.close();
		}
        // stop any previews / replays
        ls.quit();
        stop_replayer();
        mss.quit();
		MwpSpeech.close();

        if(conf.atexit != null && conf.atexit.length > 0) {
            try {
                Process.spawn_command_line_sync (conf.atexit);
            } catch {}
		}
		remove_window(window);
	}

    private void handle_replay_pause(bool from_vid=false) {
        int signum;
        magcheck = false;

        if(replay_paused) {
            signum = MwpSignals.Signal.CONT;
            time_t now;
            time_t (out now);
            armtime += (now - pausetm);
        } else {
            time_t (out pausetm);
            signum = MwpSignals.Signal.STOP;
        }
		if(!from_vid) {
			if (bbvlist != null && bbvlist.vp != null) {
				bbvlist.vp.toggle_stream();
			}
		}
        replay_paused = !replay_paused;
        if((replayer & (Player.BBOX|Player.OTX|Player.RAW)) != 0) {
            Posix.kill(child_pid, signum);
        } else {
            if(thr != null)
                robj.pause(replay_paused);
        }
    }

    private void set_menu_state(string action, bool state) {
        var ac = window.lookup_action(action) as SimpleAction;
        ac.set_enabled(state);
    }

    public SERSTATE get_serstate() {
        return serstate;
    }

    public void set_serstate(SERSTATE s = SERSTATE.NONE) {
        lastrx = lastok = nticks;
        serstate = s;
        resend_last();
    }

    private void update_menu_labels(Gtk.MenuBar  menu) {
        int done = 0;
        menu.@foreach((mi) => {
                if (mi.name == "GtkModelMenuItem") {
                    Gtk.Menu sm = (Gtk.Menu) ((Gtk.MenuItem)mi).get_submenu();
                    if (sm != null) {
                        sm.@foreach((smi) => {
                                if(smi.name == "GtkModelMenuItem") {
                                    var slbl = ((Gtk.MenuItem)smi).get_label();
                                    if (slbl.contains(" OTX ")) {
                                        if (x_aplog)
                                            slbl = slbl.replace(" OTX", " OpenTX / BulletGCSS / AP");
                                        else
                                            slbl = slbl.replace(" OTX", " OpenTX / BulletGCSS");
                                        ((Gtk.MenuItem)smi).set_label(slbl);
                                        done++;
                                        if (done == 2)
                                            return;
                                    }
                                }
                            });
                    }
                }
            });
    }

    public void handle_activate () {
        if((Posix.geteuid() == 0 || Posix.getuid() == 0) && asroot == false) {
            MWPLog.message("Cowardly refusing to run as root ... for your own safety\n");
            Posix.exit(127);
        }
        if (active_window == null) {
			show_startup();
            ready = true;
            create_main_window();
        } else {
			parse_cli_options();
		}
	}

	private string? validate_cli_file(string fn) {
		var vfn = Posix.realpath(fn);
		if (vfn == null) {
			MWPLog.message("CLI provided file \"%s\" not found\n", fn);
		}
		return vfn;
	}

	private void valid_flash() {
		var str = validatelab.get_text();
		validatelab.set_text("+");
		Timeout.add(250, () => {
				validatelab.set_text(str);
				return false;
			});
	}

    private void parse_cli_options() {
		Idle.add(() => {
				if (mission != null) {
					var fn = mission;
					mission = null;
					var vfn = validate_cli_file(fn);
					if (vfn != null) {
						var ms = open_mission_file(vfn);
						if(ms != null) {
							clat = ms.cy;
							clon = ms.cx;
							last_file = vfn;
							update_title_from_file(vfn);
						}
					}
				}

				if(kmlfile != null) {
					var ks = kmlfile.split(",");
					kmlfile = null;
                    foreach(var kf in ks) {
						var vfn = validate_cli_file(kf);
						if (vfn != null) {
							try_load_overlay(kf);
						}
					}
					valid_flash();
				}

				if(rfile != null) {
					var vfn = validate_cli_file(rfile);
					rfile = null;
					if(vfn != null) {
						run_replay(vfn, true, Player.MWP);
					}
				} else if(bfile != null) {
					var vfn = validate_cli_file(bfile);
					bfile = null;
					if(vfn != null) {
						replay_bbox(true, vfn);
					}
				} else if(otxfile != null) {
					var vfn = validate_cli_file(otxfile);
					otxfile = null;
					if(vfn != null) {
                        bbl_delay = true;
						replay_otx(vfn);
					}
				}

				return false;
			});
	}

	private void set_act_mission_combo(bool isnew=false) {
		actmission.remove_all();
		int j = 0;
		for(; j < msx.length; j++) {
			var k = j + 1;
			actmission.append_text(k.to_string());
		}
		if (j < MAXMULTI) {
			actmission.append_text("New");
		} else
			MWPLog.message("MM size exceeded\n");
        actmission.active = isnew ? j-1 : imdx;
    }

	private bool get_app_status(string app, out string bblhelp) {
        bool ok = true;
        bblhelp="";
        try {
			var bbl = new Subprocess(SubprocessFlags.STDERR_MERGE|SubprocessFlags.STDOUT_PIPE,
									 app, "--help");
			bbl.communicate_utf8(null, null, out bblhelp, null);
			bbl.wait_check_async.begin();
        } catch (Error e) {
			bblhelp = e.message;
			ok = false;
		}
        return ok;
	}

    private void create_main_window() {
        gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};
        lastmission = {};
        wpmgr = WPMGR();
		msx = {};

        // GLib version 2.73+ breaks GDL, alas
        var dbstyle = DockBarStyle.ICONS;
        if(GLib.Version.major > 1 && GLib.Version.minor > 72) {
            MWPLog.message("GLib2 %u.%u.%u (dock fallback)\n", GLib.Version.major, GLib.Version.minor, GLib.Version.micro);
            dbstyle = DockBarStyle.TEXT;
        } else {
            MWPLog.message("GLib2 %u.%u\n", GLib.Version.major, GLib.Version.minor);
        }
#if MQTT
        MWPLog.message("MQTT enabled via the \"%s\" library\n", MwpMQTT.provider());
#endif
        vbsamples = new float[MAXVSAMPLE];

        devman = new DevManager();

        hwstatus[0] = 1; // Assume OK

        conf = new MWPSettings();
        conf.read_settings();

        if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE) {
			MWPLog.message("RADAR: Maximum Altitude set to: %u\n", conf.max_radar_altitude);
		}

		MWSerial.debug = ((debug_flags & DEBUG_FLAGS.SERIAL) == DEBUG_FLAGS.SERIAL);

        wp_max = (uint8)conf.max_wps;

        string []  ext_apps = {
            conf.blackbox_decode, null, /* ex "replay_bbox_ltm.rb",*/
            "gnuplot", "mwp-plot-elevations", "unzip", null, "fl2ltm", "mavlogdump.py",
            "mwp-log-replay"};
        bool appsts[9];
        var si = 0;
		var pnf = 0;
        foreach (var s in ext_apps) {
            if (s != null) {
                appsts[si] = (Environment.find_program_in_path(s) != null);
                if (appsts[si] == false) {
					StringBuilder vsb = new StringBuilder();
					vsb.append_printf("Failed to find \"%s\" on $PATH", s);
					if(si == 0 || si > 4) {
						vsb.append("; see https://stronnag.github.io/mwptools/replay-tools/");
					}
					vsb.append_c('\n');
					MWPLog.message(vsb.str);
					pnf += 1;
				}
            }
            si++;
        }

		if(pnf > 0 && !(pnf == 1 && appsts[7] == false)) {
			MWPLog.message("FYI, PATH is %s\n", Environment.get_variable("PATH"));
		}

		if (appsts[0]) {
			string text;
			var res = get_app_status(conf.blackbox_decode, out text);
			if(res == false) {
				MWPLog.message("%s %s\n", conf.blackbox_decode, text);
			} else if (!text.contains("--datetime")) {
				MWPLog.message("\"%s\" too old, replay disabled\n", conf.blackbox_decode);
				res = false;
			}
			appsts[0] = res;
		}

		if(appsts[6]) {
			string text;
			var res = get_app_status("fl2ltm", out text);
			if(res == false) {
				MWPLog.message("fl2ltm %s\n", text);
			} else {
				var parts = text.split("\n");
				bool ok = false;
				text = "fl2ltm";
				foreach (var p in parts) {
					if (p.has_prefix("fl2ltm")) {
						int vsum = 0;
						var lparts = p.split(" ");
						if (lparts.length == 3) {
							var vparts = lparts[1].split(".");
							for(var i = 0; i < 3 && i < vparts.length; i++) {
								vsum = int.parse(vparts[i])+ 10*vsum;
							}
						}
						if (vsum > 100) {
							ok = true;
							sticks_ok = true;
						}
						text = p;
						break;
					}
				}
				if (!ok)
					MWPLog.message("\"%s\" may be too old, upgrade recommended\n", text);
				else
					MWPLog.message("Using %s\n", text);
			}
			appsts[6] = res;
		}
		if (conf.show_sticks == 1)
			sticks_ok = false;

		x_replay_bbox_ltm_rb = (appsts[0]&&appsts[6]);
		x_plot_elevations_rb = (appsts[2]&&appsts[3]);
        x_kmz = appsts[4];
		x_fl2ltm = x_otxlog = appsts[6];
		x_aplog = appsts[7];
        x_rawreplay = appsts[8];

        XmlIO.uc = conf.ucmissiontags;
        XmlIO.meta = conf.missionmetatag;
		// Ugly MM xml for the configurator
        if (Environment.get_variable("CFG_UGLY_XML") != null) {
			XmlIO.ugly = true;
		}

        pos_is_centre = conf.pos_is_centre;

        mmap = new ModelMap();
        mmap.init();

        window = builder.get_object ("window1") as Gtk.ApplicationWindow;
        this.add_window (window);
        window.set_application (this);
		window.title = "mwp";
		splash = new MwpSplash();
        if(Environment.get_variable("MWP_SPLASH") != null || is_wayland == false) {
			splash.run(/*OK*/);
		}

        spapi = 0;

        if(exvox == null) {
            StringBuilder vsb = new StringBuilder();
            if (!MwpMisc.is_cygwin()) {
                uint8 spapi_mask  = MwpSpeech.get_api_mask();
                if (spapi_mask != 0) {
                    for(uint8 j = SPEAKER_API.ESPEAK; j < SPEAKER_API.COUNT; j++) {
                        if(conf.speech_api == SPEAKERS[j] && ((spapi_mask & (1<<(j-1))) != 0)) {
                            spapi = j;
                            break;
                        }
                    }
                }
                MWPLog.message("Using speech api %d [%s]\n", spapi, SPEAKERS[spapi]);
				splash.update("Enabling speech api");
            } else {
                switch(conf.speech_api) {
                    case "espeak":
                        vsb.append("espeak");
                        if(conf.evoice.length > 0) {
                            vsb.append(" -v ");
                            vsb.append(conf.evoice);
                        }
                        break;
                    case "speechd":
                        vsb.append("spd-say -e");
                        if(conf.svoice.length > 0) {
                            vsb.append(" -t ");
                            vsb.append(conf.svoice);
                        }
                        break;
                }
                if(vsb.len > 0)
					exvox = vsb.str;
            }
        }

        if(exvox != null) {
            MWPLog.message("Using external speech api [%s]\n", exvox);
        }

        MwpSpeech.set_api(spapi);

        if(conf.uilang == "en")
            Intl.setlocale(LocaleCategory.NUMERIC, "C");

        if(layfile == null && conf.deflayout != null)
            layfile = conf.deflayout;

        var confdir = GLib.Path.build_filename(Environment.get_user_config_dir(),"mwp");
        try {
            var dir = File.new_for_path(confdir);
            dir.make_directory_with_parents ();
        } catch {};

        gpsintvl = conf.gpsintvl / TIMINTVL;

        if(conf.mediap == "false" || conf.mediap == "none") {
            MWPLog.message("Beeps disabled\n");
            beep_disabled = true;
        }

        if(rrstr != null) {
            var parts = rrstr .split(",");
            if(parts.length == 2) {
                nrings = int.parse(parts[0]);
                ringint = double.parse(parts[1]);
            }
        }

        ltm_force_sats = (Environment.get_variable("MWP_IGNORE_SATS") != null);
        var fstr = Environment.get_variable("MWP_POS_OFFSET");
        if(fstr != null) {
            string[] delims =  {","," "};
            foreach (var delim in delims) {
                var parts = fstr.split(delim);
                if(parts.length == 2) {
                    fakeoff.dlat += InputParser.get_latitude(parts[0]);
                    fakeoff.dlon += InputParser.get_longitude(parts[1]);
                    fakeoff.faking = true;
                    MWPLog.message("Faking %f %f\n", fakeoff.dlat, fakeoff.dlon);
                    break;
                }
            }
        }

        if(conf.ignore_nm == false) {
            if(offline == false) {
                try {
                    NetworkManager nm = Bus.get_proxy_sync (BusType.SYSTEM,
                                                            "org.freedesktop.NetworkManager",
                                                            "/org/freedesktop/NetworkManager");
                    NMSTATE istate = (NMSTATE)nm.State;
                    if(istate != NMSTATE.NM_STATE_CONNECTED_GLOBAL && istate != NMSTATE.UNKNOWN) {
                        offline = true;
                        MWPLog.message("Forcing proxy offline [%s]\n",
                                       istate.to_string());
                    }
                } catch {}
            }
        }

        if(conf.atstart != null && conf.atstart.length > 0) {
            try {
                Process.spawn_command_line_async(conf.atstart);
            } catch {};
        }

		MWPLog.message("Get map preference\n");
		splash.update("Setting up map sources");
        MapSource [] msources = {};
        string msfn = null;
        if(conf.map_sources != null) {
            msfn = MWPUtils.find_conf_file(conf.map_sources);
		}
        msources =   JsonMapDef.read_json_sources(msfn, offline);
		window.window_state_event.connect( (e) => {
                wdw_state = ((e.new_window_state & Gdk.WindowState.FULLSCREEN) != 0);
                if(wdw_state)  {   // true == full screen
                    if(nofsmenu)
                        window.set_show_menubar(true);
                    else
                        fsmenu_button.show();
                } else {
                    if(nofsmenu)
                        window.set_show_menubar(false);
                    else
                        fsmenu_button.hide();
                }
                return false;
        });

        dev_entry = builder.get_object ("comboboxtext1") as Gtk.ComboBoxText;
        window.set_icon_name("mwp_icon");

        arm_warn = builder.get_object ("arm_warn") as Gtk.Button;
        wp_edit_button = builder.get_object ("wp_edit_button") as Gtk.ToggleButton;
        sensor_sts[0] = builder.get_object ("gyro_sts") as Gtk.Label;
        sensor_sts[1] = builder.get_object ("acc_sts") as Gtk.Label;
        sensor_sts[2] = builder.get_object ("baro_sts") as Gtk.Label;
        sensor_sts[3] = builder.get_object ("mag_sts") as Gtk.Label;
        sensor_sts[4] = builder.get_object ("gps_sts") as Gtk.Label;
        sensor_sts[5] = builder.get_object ("sonar_sts") as Gtk.Label;

        wp_edit_button.clicked.connect(() => {
            wp_edit = !wp_edit;
            wp_edit_button.label= (wp_edit) ? "✔" : "Edit WPs";
            wp_edit_button.tooltip_text = ("Enable / disable the addition of WPs by clicking on the map (%sabled)".printf((wp_edit) ? "en" : "dis"));
            if(wp_edit) {
                FakeHome.usedby |= FakeHome.USERS.Editor;
                ls.set_fake_home();
                map_moved();
            } else {
                FakeHome.usedby &= ~FakeHome.USERS.Editor;
                ls.unset_fake_home();
            }
        });

        arm_warn.clicked.connect(() => {
                StringBuilder sb = new StringBuilder();
                if((xarm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0) {
                    sb.append("<b>Arm Status</b>\n");
                    string arm_msg = get_arm_fail(xarm_flags,'\n');
                    sb.append(arm_msg);
                }

                if(hwstatus[0] == 0) {
                    sb.append("<b>Hardware Status</b>\n");
                    for(var i = 0; i < 8; i++) {
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
        actmission = builder.get_object ("act_mission") as Gtk.ComboBoxText;
        var mm = builder.get_object ("menubar") as MenuModel;
        Gtk.MenuBar  menubar = new MenuBar.from_model(mm);

        if(x_fl2ltm) {
            update_menu_labels(menubar);
        }


        dev_protoc = builder.get_object ("dev_proto_combo") as Gtk.ComboBoxText;
		dev_protoc.changed.connect(() => {
				var pmask = (MWSerial.PMask)(int.parse(dev_protoc.active_id));
				set_pmask_poller(pmask);
			});

        this.set_menubar(mm);
        var hb = builder.get_object ("hb") as HeaderBar;
        window.set_show_menubar(false);
        hb.pack_start(menubar);

        fsmenu_button = builder.get_object("fsmenu_button") as Gtk.MenuButton;

        Gtk.Image img = new Gtk.Image.from_icon_name("open-menu-symbolic", Gtk.IconSize.BUTTON);
        fsmenu_button.add(img);
        fsmenu_button.set_menu_model(mm);
        fsmenu_button.set_use_popover(false);

        var aq = new GLib.SimpleAction("quit",null);
        aq.activate.connect(() => {
                check_mission_clean(cleanup_t, true);
            });
        this.add_action(aq);

        window.delete_event.connect(() => {
                check_mission_clean(cleanup_f, true);
                return true;
            });

        mseed = new MapSeeder(builder,window);

		var scview = builder.get_object("scwindow") as ShortcutsWindow;
		var scsect = builder.get_object("shortcuts") as ShortcutsSection;
        scview.modal = false;

		scsect.visible = true;
		scview.section_name = "shortcuts";
		scview.transient_for = window;
		scview.destroy.connect(() => {
				scview.hide();
			});
		scview.destroy.connect(() => {
				scview.hide();
			});
		scview.close.connect(() => {
				scview.hide();
			});
		scview.delete_event.connect(() => {
				scview.hide();
				return true;
			});

        msview = new MapSourceDialog(builder, window);
        setpos = new SetPosDialog(builder, window);

        navconf = new NavConfig(window, builder);
        bb_runner = new BBoxDialog(builder, window, conf.blackbox_decode,
                                   conf.logpath, fakeoff);

		bb_runner.complete.connect( (id) => {
				if(id == 1001) {
					string bblog;
					int index;
					int btype;
					uint8 force_gps = 0;
					uint duration;
					int64 nsecs;
					bb_runner.get_result(out bblog, out index, out btype,
										 out force_gps, out duration);

					if(bbvlist != null) {
						var vauto = bb_runner.get_vtimer(out nsecs);
						bbvlist.vauto = vauto;
						if (vauto) {
							bbvlist.timer = nsecs;
						};
					}
					run_replay(bblog, bbl_delay, Player.BBOX, index, btype, force_gps, duration);
				}
			});

		bb_runner.videofile.connect((uri) => {
				if (uri != null) {
					try {
						uri = Gst.filename_to_uri(uri);
						var rt = VideoPlayer.discover(uri);
						var vp = new VideoPlayer();
						vp.video_playing.connect((vstate) => {
								if((debug_flags & DEBUG_FLAGS.VIDEO) == DEBUG_FLAGS.VIDEO) {
									MWPLog.message("VIDEO: BBL is %s, video requests %s\n",
												   (replay_paused) ? "paused" : "playing",
												   (vstate) ? "playing" : "paused");
								}
								if(vstate == replay_paused) {
									handle_replay_pause(true);
								}
							});
						vp.video_closed.connect(() => {
								if((debug_flags & DEBUG_FLAGS.VIDEO) == DEBUG_FLAGS.VIDEO) {
									MWPLog.message("VIDEO: Video quits\n");
								}
								bbvlist = null;
							});
						vp.set_slider_max(rt);
						vp.set_transient_for(window);
						vp.set_keep_above(true);
						vp.show_all ();
						vp.add_stream(uri, false);
						bbvlist = {};
						bbvlist.vp = vp;
					} catch {}
				} else {
					MWPLog.message("Not playing empty video uri\n");
				}
			});

        otx_runner = new OTXDialog(builder, window, null, x_fl2ltm);
        otx_runner.ready.connect((id) => {
                otx_runner.hide();
                if(id == 1001) {
                    string fname;
                    int idx;
                    int dura;
                    int btype;
                    otx_runner.get_index(out fname, out idx, out dura, out btype);
                    run_replay(fname, bbl_delay, Player.OTX,idx,btype,0,dura);
                }
            });

        raw_runner = new RAWDialog(builder, window, null);
        raw_runner.ready.connect((id) => {
                raw_runner.hide();
                if(id == 1001) {
                    string fname;
                    int btype;
                    int rdelay;
                    raw_runner.get_name(out fname, out btype, out rdelay);
                    run_replay(fname, bbl_delay, Player.RAW, rdelay, btype,0,0);
                }
            });

        bb_runner.set_tz_tools(conf.geouser, conf.zone_detect);

        bb_runner.new_pos.connect((la, lo) => {
               try_centre_on(la, lo);
			   poslabel.label = PosFormat.pos(la,lo,conf.dms);
            });

        bb_runner.rescale.connect((llx, lly, urx,ury) => {
                if(replayer != Player.NONE) {
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


        fmdlg = new FollowMeDialog(builder, window);
        fmdlg.ready.connect((s,a) => {
                switch(s) {
                case 1:
                fmpt.show_followme(false);
                break;
                case 2:
                followme_set_wp(a); // send to vehicle
                break;
                default:
                break;
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
        dockmenus[DOCKLETS.VBOX] =  "vario-view";

        embed = new GtkChamplain.Embed();

        gps_status = new GPSStatus(builder, window);

        safehomed  = new SafeHomeDialog(window);
        safehomed.request_safehomes.connect((first, last) => {
                last_safehome = last;
                uint8 shid = first;
                queue_cmd(MSP.Cmds.SAFEHOME,&shid,1);
            });

        safehomed.notify_publish_request.connect(() => {
                safeindex = 0;
                msp_publish_home(safeindex);
            });

        Places.get_places();
        setpos.load_places();
        setpos.new_pos.connect((la, lo, zoom) => {
				Idle.add(() => {
						map_centre_on(la, lo);
						if(zoom > 0)
							view.zoom_level = zoom;
						map_moved();
						valid_flash();
						return false;
					});
            });

        var saq = new GLib.SimpleAction("file-open",null);
        saq.activate.connect(() => {
                check_mission_clean(on_file_openf);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("file-append",null);
        saq.activate.connect(() => {
                check_mission_clean(on_file_opent);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("menu-save",null);
        saq.activate.connect(() => {
                on_file_save();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("menu-save-as",null);
        saq.activate.connect(() => {
                on_file_save_as(null);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("prefs",null);
        saq.activate.connect(() => {
                prefs.run_prefs(conf);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("followme",null);
        saq.activate.connect(() => {
                fmdlg.unhide();
                if (!fmpt.has_location()) {
                    fmpt.set_followme(view.get_center_latitude(), view.get_center_longitude());
                }
                fmpt.show_followme(true);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("mman",null);
        saq.activate.connect(() => {
				var dialog = new MDialog (msx);
				dialog.remitems.connect((mitem) => {
						mm_regenerate(mitem);
					});
				dialog.show ();
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
                setpos.load_places();
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
                                     serstate == SERSTATE.NORMAL)) {
                    wpmgr.wp_flag |= WPDL.GETINFO;
                    queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("terminal",null);
        saq.activate.connect(() => {
                if(msp.available && armed == 0) {
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
                if(msp.available && armed == 0) {
                    queue_cmd(MSP.Cmds.REBOOT,null, 0);
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("audio",null);
        saq.activate.connect(() => {
                var aon = audio_cb.active;
                if(aon == false) {
                    audio_cb.active = true;
                }
                navstatus.audio_test();
                if(aon == false) {
                    Timeout.add(1000, () => {
                            audio_cb.active = false;
                            return false;
                        });
                }
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("map-source",null);
        saq.activate.connect(() => {
                var map_source_factory = Champlain.MapSourceFactory.dup_default();
                var sources =  map_source_factory.get_registered();
                foreach (Champlain.MapSourceDesc sr in sources) {
                    if(view.map_source.get_id() == sr.get_id()) {
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
                if(!gps_status.visible) {
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

        saq = new GLib.SimpleAction("manual",null);
        saq.activate.connect(() => {
				try {
					Gtk.show_uri_on_window (null, "https://stronnag.github.io/mwptools/",
											Gdk.CURRENT_TIME);
				} catch {}
			});
		window.add_action(saq);

        saq = new GLib.SimpleAction("upload-mission",null);
        saq.activate.connect(() => {
                upload_mm(mdx, WPDL.GETINFO);
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("upload-missions",null);
        saq.activate.connect(() => {
                upload_mm(-1, WPDL.GETINFO|WPDL.SET_ACTIVE);
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
                upload_mm(-1, WPDL.SAVE_EEPROM|WPDL.SET_ACTIVE);
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

        saq = new GLib.SimpleAction("replay-otx",null);
        saq.activate.connect(() => {
                bbl_delay = true;
                replay_otx();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("load-otx",null);
        saq.activate.connect(() => {
                bbl_delay = true;
                replay_otx();
            });
        window.add_action(saq);
        saq = new GLib.SimpleAction("replayraw",null);
        saq.activate.connect(() => {
                replay_raw();
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

        saq = new GLib.SimpleAction("safe-homes",null);
        saq.activate.connect(() => {
                safehomed.show(window);
            });
        window.add_action(saq);

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

		saq = new GLib.SimpleAction("vstream",null);
        saq.activate.connect(() => {
                load_v4l2_video();
            });
        window.add_action(saq);

		var lsaq = new GLib.SimpleAction.stateful ("locicon", null, false);
		lsaq.change_state.connect((s) => {
				var b = s.get_boolean();
				GCSIcon.default_location(view.get_center_latitude(),
									 view.get_center_longitude());
				GCSIcon.set_visible(b);
				lsaq.set_state (s);
		});
		window.add_action(lsaq);

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
        saq = new GLib.SimpleAction("vario-view",null);
        saq.activate.connect(() => {
                show_dock_id(DOCKLETS.VBOX, true);
            });
        window.add_action(saq);
        saq = new GLib.SimpleAction("radar-view",null);
        saq.activate.connect(() => {
                radarv.show_or_hide();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("ttrack-view",null);
        saq.activate.connect(() => {
                ttrk.show_dialog();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("keys",null);
        saq.activate.connect(() => {
                scview.show_all();
            });

        window.add_action(saq);

        reboot_status();

        set_replay_menus(true);
        set_menu_state("upload-mission", false);
        set_menu_state("upload-missions", false);
        set_menu_state("download-mission", false);
        set_menu_state("restore-mission", false);
        set_menu_state("store-mission", false);
        set_menu_state("navconfig", false);
        set_menu_state("stop-replay", false);
        set_menu_state("mission-info", false);
        set_menu_state("followme", false);

        art_win = new ArtWin(conf.ah_inv_roll);

        var css = new Gtk.CssProvider ();
        var screen = Gdk.Screen.get_default();
        try {
            string cssfile = MWPUtils.find_conf_file("vcols.css");
            MWPLog.message("Loaded %s\n", cssfile);
            css.load_from_file(File.new_for_path(cssfile));
            Gtk.StyleContext.add_provider_for_screen(screen, css, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        } catch (Error e) {
            stderr.printf("context %s\n", e.message);
        }
        vcol = new VCol();

        MonoFont.fixed = conf.fixedfont;
        MWPLog.message("Fixed font %s\n", MonoFont.fixed.to_string());

        odoview = new OdoView(builder,window,conf.stats_timeout);
        navstatus = new NavStatus(builder, vcol, conf.recip);
        radstatus = new RadioStatus(builder);
        telemstatus = new TelemetryStats(builder);
        fbox  = new FlightBox(builder,window);
        dbox = new DirnBox(builder, conf.horizontal_dbox);
        vabox = new VarioBox();
        radarv = new RadarView(window);
        radarv.vis_change.connect((vh) => {
                markers.rader_layer_visible(vh);
            });

        radarv.zoom_to_swarm.connect((y, x) =>{
                view.center_on(y,x);
            });

		view = embed.get_view();
        view.set_reactive(true);
		view.animate_zoom = true;

        var place_editor = new PlaceEdit(window, view);
        setpos.place_edit.connect(() => {
                place_editor.show();
            });

        place_editor.places_changed.connect(() => {
                setpos.load_places();
                place_editor.hide();
            });

        fmpt = new FollowMePoint (view);
        fmpt.fmpt_move.connect((la, lo) => {
                double dist=0,cse=0;
                Geo.csedist(GPSInfo.lat, GPSInfo.lon, la, lo, out dist, out cse);
                string lbl = "%s (%.0fm, %0.f°)".printf(PosFormat.pos(la, lo, conf.dms), dist*1852, cse);
                fmdlg.set_label(lbl);
            });

        safehomed.set_view(view);
        if(conf.load_safehomes != "") {
            var parts = conf.load_safehomes.split(",");
            bool disp = (parts.length == 2 && (parts[1] == "Y" || parts[1] == "y"));
            safehomed.load_homes(parts[0],disp);
        }

        if(conf.arming_speak)
            say_state=NavStatus.SAY_WHAT.Arm;

        navstatus.set_audio_status(say_state);

        view.notify["zoom-level"].connect(() => {
                var val = view.get_zoom_level();
                var zval = (int)zoomer.adjustment.value;
                if (val != zval)
                    zoomer.adjustment.value = (int)val;
                get_map_size();
                map_moved();
            });


		actmission.changed.connect(() => {
				var s = actmission.get_active_text();
				if (s == null)
					return;

				if(!ms_from_loader && msx.length > 0) {
					msx[mdx] = ls.to_mission();
				}
				if (s == "New") {
					mdx = msx.length;
					msx += new Mission();
                    instantiate_mission(msx[mdx]);
                    set_act_mission_combo(true);
				} else {
					mdx = actmission.active;
                    if(msx[mdx].npoints > 0) {
                        instantiate_mission(msx[mdx]);
                    } else {
                        clear_mission();
                    }
                }
			});

		zoomer.adjustment.value_changed.connect (() => {
                int  zval = (int)zoomer.adjustment.value;
                var val = view.get_zoom_level();
                if (val != zval) {
                    view.zoom_level = zval;
                    map_moved();
                }
            });

        conf.settings_update.connect ((s) => {
                if (s == "display-dms" ||
                    s == "default-latitude" ||
                    s == "default-longitide")
                    anim_cb(true);

                if(s == "display-dms" ||
                    s == "display-distance" ||
                    s == "display-speed") {
                    fbox.update(item_visible(DOCKLETS.FBOX));
                }
            });

        view.set_keep_center_on_resize(true);

        prefs = new PrefsDialog(builder, window);
        prefs.done.connect((id) => {
                if(id  == 1001) {
                    prefs.update_conf(ref conf);
                    build_serial_combo();
                    if(conf.speakint == 0)
                        conf.speakint = 15;
                    audio_cb.sensitive = true;
                }
            });

        add_source_combo(conf.defmap,msources);

        mlayer = new MeasureLayer(window, view);

        var ag = new Gtk.AccelGroup();
        ag.connect('d', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                int mx = 0;
                int my = 0;
                Gdk.Display display = Gdk.Display.get_default ();
                var seat = display.get_default_seat();
                var ptr = seat.get_pointer();
                embed.get_window().get_device_position(ptr, out mx, out my, null);
                mlayer.toggle_state(window, view, mx ,my);
                return true;
          });

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
                if(craft != null) {
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

        ag.connect('t', Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK, 0, (a,o,k,m) => {
                ttrk.show_dialog();
                return true;
            });


        ag.connect('c', Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK, 0, (a,o,k,m) => {
                       connect_serial();
                       return true;
                   });

        ag.connect('v', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                MissionPix.get_mission_pix(embed, markers, ls.to_mission(), last_file);
                return true;
            });

        ag.connect('w', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                if(conf.auto_wp_edit == false)
                    wp_edit_button.active = !wp_edit;
                return true;
            });


        ag.connect('h', Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK, 0, (a,o,k,m) => {
                ls.toggle_fake_home();
                return true;
            });

        ag.connect('z', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                clear_mission();
                wpmgr.wps = {};
                return true;
            });

        ag.connect('k', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
				wpmgr.wp_flag = WPDL.CANCEL;
                return true;
            });

        ag.connect('h', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                map_centre_on(conf.latitude,conf.longitude);
                return true;
            });

        ag.connect(' ', 0, 0, (a,o,k,m) => {
                if(replayer != Player.NONE) {
                    handle_replay_pause();
                    return true;
                }
                else return false;
            });

        ag.connect('x', Gdk.ModifierType.CONTROL_MASK, 0, (a,o,k,m) => {
                ls.toggle_mission_preview_state();
                return true;
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
		pane.wide_handle = true;

        markers = new MWPMarkers(ls,view, conf.wp_spotlight);

        ls.connect_markers();

		GCSDebug.debug = ((debug_flags & DEBUG_FLAGS.GCSLOC) == DEBUG_FLAGS.GCSLOC);
		GCSIcon.gcs_icon();
        poslabel = builder.get_object ("poslabel") as Gtk.Label;
        MonoFont.apply(poslabel);

        stslabel = builder.get_object ("missionlab") as Gtk.Label;
        statusbar = builder.get_object ("statusbar1") as Gtk.Statusbar;
        context_id = statusbar.get_context_id ("Starting");
        elapsedlab =  builder.get_object ("elapsedlab") as Gtk.Label;
        MonoFont.apply(elapsedlab);

        logb = builder.get_object ("logger_cb") as Gtk.CheckButton;
        logb.toggled.connect (() => {
                if (logb.active) {
                    Logger.start(conf.logsavepath);
                    if(armed != 0) {
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
                if (audio_on) {
                    start_audio();
                } else {
                    stop_audio();
                }
            });

        audio_cb.button_release_event.connect (() => {
                if(audio_cb.active) {
                    if((debug_flags & DEBUG_FLAGS.ADHOC) != 0)
                        MWPLog.message("Disable nav speak\n");
                    say_state &= ~NavStatus.SAY_WHAT.Nav;
                } else {
                    if((debug_flags & DEBUG_FLAGS.ADHOC) != 0)
                        MWPLog.message("Enable nav speak\n");
                    say_state |= NavStatus.SAY_WHAT.Nav;
                }
                navstatus.set_audio_status(say_state);
                return false;
            });

        var centreonb = builder.get_object ("checkbutton1") as Gtk.CheckButton;
        if(conf.use_legacy_centre_on)
            centreonb.set_label("Centre On");

        centreonb.active = centreon = conf.centreon;
        centreonb.toggled.connect (() => {
                centreon = centreonb.active;
            });

        var followb = builder.get_object ("checkbutton2") as Gtk.CheckButton;
        if(conf.autofollow) {
            follow = true;
            followb.active = true;
        }

        followb.toggled.connect (() => {
                follow = followb.active;
                if (follow == false && craft != null) {
                    craft.park();
                }
            });

        swd = new SwitchDialog(builder, window);
        about = builder.get_object ("aboutdialog1") as Gtk.AboutDialog;
        about.set_transient_for(window);
        StringBuilder sb = new StringBuilder(MwpVers.get_build());
        sb.append_c('\n');
        sb.append(MwpVers.get_id());
        sb.append_printf("\non %s\n", xlib);
        about.version = sb.str;

        about.copyright = "© 2014-%d Jonathan Hudson".printf(
            new DateTime.now_local().get_year());

        msp = new MWSerial();
        msp.use_v2 = false;
        if (relaxed) {
            MWPLog.message("using \"relaxed\" MSP for main port\n");
            msp.set_relaxed(true);
        }

        if(forward_device != null)
            fwddev = new MWSerial.forwarder();

        radar_plot = new SList<RadarPlot?>();


		foreach (var rd in radar_device) {
			var parts = rd.split(",");
			foreach(var p in parts) {
				var pn = p.strip();
				if (pn.has_prefix("sbs://")) {
					var sbs = new SbsReader(pn);
					sbs.read_sbs.begin();
					sbs.sbs_result.connect((s) => {
							if (s == null) {
								Timeout.add_seconds(60, () => {
										sbs.read_sbs.begin();
										return false;
									});
							} else {
								var px = sbs.parse_sbs_message(s);
								if (px != null) {
									decode_sbs(px);
								}
							}
						});
				} else {
					RadarDev r = {};
					r.name = pn;
					MWPLog.message("Set up radar device %s\n", r.name);
					r.dev = new MWSerial();
					r.dev.set_mode(MWSerial.Mode.SIM);
					r.dev.set_pmask(MWSerial.PMask.INAV);
					r.dev.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
							handle_radar(s, cmd,raw,len,xflags,errs);
						});
					radardevs += r;
				}
			}
			if(radardevs.length > 0) {
				try_radar_dev();
				Timeout.add_seconds(15, () => {
						try_radar_dev();
						return Source.CONTINUE;
					});
			}
		}

        ttrk = new TelemTracker(this);
        mq = new Queue<MQI?>();

        build_serial_combo();
        dev_entry.active = 0;
#if MQTT
        mqtt = newMwpMQTT();
        mqtt.mqtt_mission.connect((w,n) => {
                wp_resp = {};
                for(var j = 0; j < n; j++) {
                    wp_resp += wp_to_mitem(w[j]);
                }
                clear_mission();
                var ms = new Mission();
                ms.set_ways(wp_resp);

                ls.import_mission(ms, (conf.rth_autoland && Craft.is_mr(vi.mrtype)));
                markers.add_list_store(ls);
                NavStatus.nm_pts = (uint8)wp_resp.length;
                NavStatus.have_rth = (wp_resp[n-1].action == MSP.Action.RTH);
                check_mission_home();
				msx[mdx] = ms;
            });
        mqtt.mqtt_frame.connect((cmd, raw, len) => {
                handle_serial(cmd,raw,(uint)len,0, false);
            });

        mqtt.mqtt_craft_name.connect((s) => {
                vname = s;
                set_typlab();
            });

#endif
        devman.device_added.connect((s) => {
                if(s != null && s.contains(" ") || msp.available)
                    append_combo(dev_entry, s);
                else
                    prepend_combo(dev_entry, s);
            });
        devman.device_removed.connect((s) => {
                remove_combo(dev_entry, s);
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

        if(fakeoff.faking) {
            clat += fakeoff.dlat;
            clon += fakeoff.dlon;
        }

        kmls = new Array<KmlOverlay>();

        if(llstr != null) {
			var llok = false;
            string[] delims =  {","," "};
			var nps = 0;
            foreach (var delim in delims) {
                var parts = llstr.split(delim);
				if(parts.length >= 2) {
					foreach(var pp in parts) {
						var ps = pp.strip();
						if(InputParser.posok(ps)) {
							switch (nps) {
							case 0:
								clat = InputParser.get_latitude(ps);
								nps = 1;
								break;
							case 1:
								clon = InputParser.get_longitude(ps);
								nps = 2;
								break;
							case 2:
								zm = int.parse(parts[2]);
								break;
							default:
								break;
							}
						}
					}
					if (nps >= 2) {
						llok = true;
						break;
					}
				}
			}

			if (!llok) {
				var pls = Places.points();
				foreach(var pl in pls) {
					if (pl.name == llstr) {
						clat = pl.lat;
						clon = pl.lon;
						if (pl.zoom > -1) {
							zm = (uint)pl.zoom;
						}
						break;
					}
				}
			}
        }
        map_centre_on(clat, clon);
        if (check_zoom_sanity(zm))
            view.zoom_level = zm;

        msp.force4 = force4;
        msp.serial_lost.connect(() => { serial_doom(conbutton); });

        msp.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
                handle_serial(cmd,raw,len,xflags,errs);
            });

        msp.crsf_event.connect((raw) => {
				ProcessCRSF(raw);
            });

        msp.flysky_event.connect((raw) => {
				ProcessFlysky(raw);
            });

        msp.sport_event.connect((id,val) => {
                process_sport_message ((SportDev.FrID)id, val);
            });

        if(serial != null) {
            dev_entry.prepend_text(serial);
            dev_entry.active = 0;
        }

        autocon_cb.toggled.connect(() => {
                autocon =  autocon_cb.active;
                autocount = 0;
            });

        if(conf.vlevels != null) {
            string [] parts;
            parts = conf.vlevels.split(";");
            var i = 0;
            foreach (unowned string str in parts) {
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

		sticks = new Sticks.StickWindow(window, conf.show_sticks);

//        Timeout.add_seconds(5, () => { return try_connect(); });
        if(set_fs)
            window.fullscreen();
        else if (no_max == false)
            window.maximize();
        else {
            Gdk.Rectangle rect = {0,0};
            if(get_primary_size(ref rect)) {
                var rw = rect.width*80/100;
                var rh = rect.height*80/100;
                window.resize(rw,rh);
            }
        }

		window.configure_event.connect((e) => {
                if( !((e.width == window_w) && (e.height == window_h))) {
                    window_w  = e.width;
                    window_h = e.height;
                    var nppos = conf.window_p * (double)(pane.max_position - pane.min_position) /100.0;
                    pane.position = (int)Math.lround(nppos);
                    Idle.add(() => {
                            fbox.check_size();
                            return Source.REMOVE;
                        });
                    get_map_size();
                    map_warn_set_text();
				}
				return false;
			});

        pane.button_press_event.connect((evt) => {
                fbox.allow_resize(true);
                return false;
            });

        pane.button_release_event.connect((evt) => {
                if (evt.button == 1) {
                    conf.window_p = 100.0* (double)pane.position /(double) (pane.max_position - pane.min_position);
                    conf.save_pane();
                }
                Timeout.add(500, () => {
                            fbox.allow_resize(false);
                        return Source.REMOVE;
                    });
                return false;
            });
		MWPLog.message("Show main window\n");
		splash.update("Preparing main window");

        if((wp_edit = conf.auto_wp_edit) == true)
            wp_edit_button.hide();
        else
            wp_edit_button.show();

        if(wdw_state == false)
            fsmenu_button.hide();

        arm_warn.hide();

            // not anim_cb() as we just want the centre, regardless
        poslabel.set_text(PosFormat.pos(view.get_center_latitude(),
                                            view.get_center_longitude(),
                                            conf.dms));
        var scale = new Champlain.Scale();
        scale.connect_view(view);
        view.add_child(scale);
        Clutter.LayoutManager lm = view.get_layout_manager();
        lm.child_set(view,scale,"x-align", Clutter.ActorAlign.START);
        lm.child_set(view,scale,"y-align", Clutter.ActorAlign.END);
        map_init_warning(lm);
		bool minit = false;
		view.layer_relocated.connect(() => {
				if (!minit) {
					minit = true;
					Timeout.add(100, () => {
							parse_cli_options();
							return false;
						});
				}
			});

		window.show_all();

        var dock = new Dock ();
        dock.margin_start = 4;
        var dockbar = new DockBar (dock);

        dockbar.set_style (dbstyle);
        lman = new LayMan(dock, confdir,layfile,DOCKLETS.NUMBER);

        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);

        dockitem = new DockItem[DOCKLETS.NUMBER];
		var icon_theme = IconTheme.get_default();
		foreach(var di in ddefs) {
			try {
				var px = icon_theme.load_icon (di.icon, IconSize.BUTTON, IconLookupFlags.FORCE_SVG|IconLookupFlags.USE_BUILTIN);
				dockitem[di.tag]= new DockItem.with_pixbuf_icon (di.id, di.name, px, DockItemBehavior.NORMAL);
				if((debug_flags&DEBUG_FLAGS.ADHOC) == DEBUG_FLAGS.ADHOC) {
					MWPLog.message("DICON-DBG %d %s %s %s\n", di.tag, di.id, di.name, di.icon);
				}
			} catch {
				dockitem[di.tag]= new DockItem.with_stock (di.id, di.name, di.stock, DockItemBehavior.NORMAL);
				if((debug_flags&DEBUG_FLAGS.ADHOC) == DEBUG_FLAGS.ADHOC) {
					MWPLog.message("DSTOCK-DBG %d %s %s %s (%s)\n", di.tag, di.id, di.name, di.stock, di.icon);
				}
			}
		}

        dockitem[DOCKLETS.VOLTAGE].add (navstatus.voltbox);
        dockitem[DOCKLETS.MISSION].add (scroll);
        dockitem[DOCKLETS.GPS].add (grid);
        dockitem[DOCKLETS.NAVSTATUS].add (navstatus.grid);
        dockitem[DOCKLETS.RADIO].add (radstatus.box);
        dockitem[DOCKLETS.TELEMETRY].add (telemstatus.grid);
        dockitem[DOCKLETS.FBOX].add (fbox.vbox);
        dockitem[DOCKLETS.DBOX].add (dbox.dbox);
        dockitem[DOCKLETS.VBOX].add (vabox.vbox);
        dockitem[DOCKLETS.ARTHOR].add (art_win.box);

        dock.add_item (dockitem[DOCKLETS.ARTHOR], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.GPS], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.NAVSTATUS], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.VOLTAGE], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.TELEMETRY], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.RADIO], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.FBOX], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.DBOX], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.VBOX], DockPlacement.BOTTOM);
        dock.add_item (dockitem[DOCKLETS.MISSION], DockPlacement.BOTTOM);
        box.show_all();

        if(!lman.load_init()) {
            dockitem[DOCKLETS.ARTHOR].iconify_item ();
            dockitem[DOCKLETS.GPS].iconify_item ();
            dockitem[DOCKLETS.NAVSTATUS].iconify_item ();
            dockitem[DOCKLETS.VOLTAGE].iconify_item ();
            dockitem[DOCKLETS.RADIO].iconify_item ();
            dockitem[DOCKLETS.TELEMETRY].iconify_item ();
            dockitem[DOCKLETS.FBOX].iconify_item ();
            dockitem[DOCKLETS.DBOX].iconify_item ();
            dockitem[DOCKLETS.VBOX].iconify_item ();
            lman.save_config();
        }

        mwpdh = new MwpDockHelper(dockitem[DOCKLETS.MISSION], dock,
                          "Mission Editor", conf.tote_floating);
        mwpdh.transient(window);

        mwpdh.menu_key.connect(() => {
                ls.show_tote_popup(null);
            });

        dockitem[DOCKLETS.MISSION].hide.connect(() => {
                ls.unset_selection();
            });
        fbox.update(true);

        if(conf.mavph != null)
            parse_rc_mav(conf.mavph, Craft.Special.PH);

        if(conf.mavrth != null)
            parse_rc_mav(conf.mavrth, Craft.Special.RTH);

		setup_mission_from_mm();

        Gtk.drag_dest_set (window, Gtk.DestDefaults.ALL,
                           targets, Gdk.DragAction.COPY);

		window.drag_data_received.connect((ctx, x, y, data, info, time) => {
                foreach(var uri in data.get_uris ()) {
					guess_content_type(uri);
                }
                Gtk.drag_finish (ctx, true, false, time);
				parse_cli_options();
            });

		setup_buttons();
		set_dock_menu_status();
		dock.layout_changed.connect(() => {
				set_dock_menu_status();
			});

		get_map_size();

		acquire_bus();

		splash.destroy();

		if(mkcon) {
            connect_serial();
        }

        if(autocon) {
            autocon_cb.active=true;
            mkcon = true;
            try_connect();
        }

        if(conf.mag_sanity != null) {
            var parts=conf.mag_sanity.split(",");
            if (parts.length == 2) {
                magdiff=int.parse(parts[0]);
                magtime=int.parse(parts[1]);
                MWPLog.message("Enabled mag anomaly checking %d⁰, %ds\n", magdiff,magtime);
                magcheck = true;
            }
        }

        pstate = new PowerState();
        if(pstate.init()) {
            MWPLog.message("%s\n", pstate.show_status());
            pstate.host_power_alert.connect((s) => {
                    audio_cb.active = true; // the user will hear this ...
                    navstatus.host_power(s);
                    MWPLog.message("%s\n", s);
                    mwp_warning_box(s, Gtk.MessageType.ERROR, 30);
                });
        }

        if(conf.manage_power) {
            MWPLog.message("mwp will manage power and screen saver / idle\n");
            dtnotify = new MwpNotify();
        }

		viddevs = new List<GstMonitor.VideoDev?> ();
		CompareFunc<GstMonitor.VideoDev?>  devname_comp = (a,b) =>  {
			return strcmp(a.devicename, b.devicename);
		};
		viddev_c = new Gtk.ComboBoxText();
		var gstdm = new GstMonitor();
		gstdm.source_changed.connect((a,d) => {
				bool act = false;
				switch (a) {
				case "add":
				case "init":
					if(viddevs.find_custom(d, devname_comp) == null) {
						viddevs.append(d);
						viddev_c.append(d.devicename, d.displayname);
						viddev_c.active_id = d.devicename;
						act = true;
					}
					break;
				case "remove":
					unowned List<GstMonitor.VideoDev?> da  = viddevs.find_custom(d, devname_comp);
					if (da != null) {
						viddevs.remove_link(da);
						remove_combo(viddev_c, d.displayname);
						act = true;
					}
					break;
				}
				if(act)
					MWPLog.message("GST: \"%s\" <%s> <%s>\n", a, d.displayname, d.devicename);
				if((debug_flags & DEBUG_FLAGS.VIDEO) == DEBUG_FLAGS.VIDEO) {
					//					viddevs.@foreach((d) =>
					for (unowned List<GstMonitor.VideoDev?>lp = viddevs.first(); lp != null; lp = lp.next)  {
						var dv = lp.data;
						MWPLog.message("VideoDevs <%s> <%s>\n", dv.devicename, dv.displayname);
					}
				}
			});
		gstdm.setup_device_monitor();
		map_moved();
    }

	private void set_pmask_poller(MWSerial.PMask pmask) {
		if (pmask == MWSerial.PMask.AUTO || pmask == MWSerial.PMask.INAV) {
			nopoll = false;
		} else {
			xnopoll = nopoll;
			nopoll = true;
		}
		msp.set_pmask(pmask);
		msp.set_auto_mpm(pmask == MWSerial.PMask.AUTO);
	}

	private void guess_content_type(string uri) {
		string? fn = null;
		try {
			if (uri.has_prefix("file://")) {
				fn = Filename.from_uri(uri);
			} else {
				fn = uri;
			}

			uint8 buf[1024]={0};
			uint8 []? pbuf = null;
			var fs = FileStream.open (fn, "r");
			if (fs != null) {
				if(fs.read (buf) > 0) {
					pbuf=buf;
				}
			}
			var mt = GLib.ContentType.guess(fn, pbuf, null);

			switch (mt) {
			case "application/vnd.mw.mission":
			case "application/vnd.mwp.json.mission":
				mission = fn;
				break;
			case "application/vnd.blackbox.log":
				bfile = fn;
				break;
			case "application/vnd.otx.telemetry.log":
				otxfile = fn;
				break;
			case "application/vnd.mwp.log":
				rfile = fn;
				break;
			case "application/vnd.google-earth.kmz":
				if(x_kmz)
					add_kml(fn);
				break;
			case "application/vnd.google-earth.kml+xml":
				add_kml(fn);
				break;
			default:
				break;
			}
		} catch {}
	}

    private void followme_set_wp(int alt) {
        uint8 buf[32];
        double lat =0, lon = 0;
        double dist =0,cse = 0;
        fmpt.get_followme(out lat, out lon);
        Geo.csedist(GPSInfo.lat, GPSInfo.lon, lat, lon, out dist, out cse);
        MWPLog.message("DBG: SET lat=%.6f lon=%.6f %.0fm %.0f°\n", lat, lon, dist*1852.0, cse);
        MSP_WP [] wps={};
        MSP_WP wp = MSP_WP();
        wp.wp_no = 255;
        wp.action =  MSP.Action.WAYPOINT;
        wp.lat = (int32)(lat*1e7);
        wp.lon = (int32)(lon*1e7);
        wp.altitude = (int32)alt*100;
        wp.p1 = (int16)cse; // heading
        wp.p2 = wp.p3 = 0;
        wp.flag = 0xa5;
        wps += wp;
		wpmgr.npts = (uint8)wps.length;
        wpmgr.wpidx = 0;
        wpmgr.wps = wps;
        wpmgr.wp_flag = WPDL.FOLLOW_ME;
        var nb = serialise_wp(wp, buf);
        MWPLog.message("DBG act=%d la=%d lo=%d alt=%d cse=%d\n", wp.action, wp.lat,  wp.lon, wp.altitude, wp.p1);
        queue_cmd(MSP.Cmds.SET_WP, buf, nb);
    }

	private void add_kml(string fn) {
		if(kmlfile == null) {
			kmlfile = fn;
		} else {
			kmlfile = string.join(",", kmlfile, fn);
		}
	}

#if MQTT
	private MissionItem wp_to_mitem(MSP_WP w) {
		MissionItem m = MissionItem();
		m.no= w.wp_no;
		m.action = (MSP.Action)w.action;
		m.lat = w.lat/10000000.0;
		m.lon = w.lon/10000000.0;
		m.alt = w.altitude/100;
		m.param1 = w.p1;
		if(m.action == MSP.Action.SET_HEAD &&
		   conf.recip_head  == true && m.param1 != -1) {
			m.param1 = (m.param1 + 180) % 360;
		}
		m.param2 = w.p2;
		m.param3 = w.p3;
		m.flag = w.flag;
		return m;
	}
#endif

	private void mm_regenerate(uint mitem) {
		Mission [] mmsx = {};
		for(var j = 0; j < msx.length; j++) {
			if ((mitem & (1 << j)) == 0) {
				mmsx += msx[j];
			}
		}
		imdx = 0;
		msx = mmsx;
		clear_mission();
		setup_mission_from_mm();
	}

	public void mwp_notify(string s) {
        var notification = new Notification ("mwp");
        notification.set_body (s);
        var icon = new GLib.ThemedIcon ("dialog-warning");
        notification.set_icon (icon);
        send_notification ("mwp", notification);
    }

    public uint8 get_mrtype() {
        return vi.mrtype;
    }

    private void try_load_overlay(string kf) {
        var kml = new KmlOverlay(view);
        if(kml.load_overlay(kf)) {
            kmls.append_val (kml);
            set_menu_state("kml-remove", true);
        }
    }

    private bool is_kml_loaded(string name) {
        var found = false;
        for (int i = 0; i < kmls.length ; i++) {
            if(name == kmls.index(i).get_filename()) {
                found = true;
                break;
            }
        }
        return found;
    }

	private void load_v4l2_video() {
		string uri = null;
		Gst.ClockTime rt = 0;
        int res = -1;
		if (vid_dialog == null) {
			vid_dialog = new V4L2_dialog(viddev_c);
            vid_dialog.response.connect((id) => {
                if(id == 1000) {
                    res = vid_dialog.result(out uri);
                    switch(res) {
                    case 0:
                        if (viddev_c.active_id != null) {
                            uri = "v4l2://%s".printf(viddev_c.active_id);
                        } else {
                            res = -1;
                        }
                        break;
                    case 1:
                        uri = uri.strip();
                        if (uri.length > 0) {
                            if (uri.has_prefix("~")) {
                                var h = Environment.get_home_dir();
                                uri = h + uri[1:uri.length];
                            }
                            if (!uri.contains("""://""")) {
                                try {
                                    uri = Gst.filename_to_uri(uri);
                                    rt = VideoPlayer.discover(uri);
                                } catch {}
                            }
                        } else {
                            MWPLog.message("Not playing empty video uri\n");
                            res = -1;
                        }
                        break;
                    }
                }
                vid_dialog.hide();
                if (res != -1) {
                    var vp = new VideoPlayer();
                    vp.set_slider_max(rt);
                    vp.set_transient_for(window);
                    vp.set_keep_above(true);
                    vp.show_all ();
                    vp.add_stream(uri);
                }
            });
        }
        vid_dialog.show_all();
	}

    private void kml_load_dialog() {
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
        if(x_kmz) {
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
        if(conf.kmlpath != null)
            chooser.set_current_folder (conf.kmlpath);

        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    var fns = chooser.get_filenames ();
                    chooser.close ();
                    foreach(var fn in fns) {
                        if(is_kml_loaded(fn) == false)
                            try_load_overlay(fn);
                    }
                } else
                    chooser.close ();
            });
        chooser.show_all();
    }

    private void kml_remove_dialog() {
        var dialog = new Dialog.with_buttons ("Remove KML", null,
                                              DialogFlags.DESTROY_WITH_PARENT,
                                              "Cancel", ResponseType.CANCEL,
                                              "OK", ResponseType.OK);

        Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        var content = dialog.get_content_area ();
        content.pack_start (box, false, false, 0);

        CheckButton[] btns = {};

        for (int i = 0; i < kmls.length ; i++) {
            var s = kmls.index(i).get_filename();
            var button = new Gtk.CheckButton.with_label(s);
            btns += button;
            box.pack_start (button, false, false, 0);
        }

        box.show_all ();
		dialog.show();
        dialog.response.connect((resp) => {
                if (resp == ResponseType.OK) {
                    var i = btns.length;
                    foreach (var b in btns) {
                        i--;
                        if(b.get_active()) {
                            kmls.index(i).remove_overlay();
                            kmls.remove_index(i);
                        }
                    }
                }
                set_menu_state("kml-remove", (kmls.length != 0));
                dialog.destroy ();
            });
    }

    private void remove_all_kml() {
        for (int i = 0; i < kmls.length ; i++) {
            kmls.index(i).remove_overlay();
        }
        kmls.remove_range(0,kmls.length);
        set_menu_state("kml-remove", false);
    }

    private uint8 sport_parse_lat_lon(uint val, out int32 value) {
        uint8 imode = (uint8)(val >> 31);
        value = (int)(val & 0x3fffffff);
        if ((val & (1 << 30))!= 0)
            value = -value;
        value = (50*value) / 3; // min/10000 => deg/10000000
        return imode;
    }

	private void crsf_analog() {
		MSP_ANALOG an = MSP_ANALOG();
		an.rssi = CRSF.teledata.rssi;
		an.vbat = (uint8)(CRSF.teledata.volts * 10);
		an.powermetersum = (conf.smartport_fuel == 2 )? (uint16)curr.mah :0;
		an.amps = curr.centiA;
		process_msp_analog(an);
	}

	private void ProcessCRSF(uint8 []buffer) {
		if(!CRSF.teledata.setlab) {
			verlab.label = verlab.tooltip_text = "CRSF telemetry";
			CRSF.teledata.setlab = true;
			xnopoll = nopoll;
			nopoll = true;
			serstate = SERSTATE.TELEM;
		}

		uint8 id = buffer[2];
		uint8 *ptr = &buffer[3];
		uint32 val32;
		uint16 val16;
		switch(id) {
		case CRSF.GPS_ID:
			ptr= SEDE.deserialise_u32(ptr, out val32);  // Latitude (deg * 1e7)
			int32 lat = (int32)Posix.ntohl(val32);
			ptr= SEDE.deserialise_u32(ptr, out val32); // Longitude (deg * 1e7)
			int32 lon = (int32)Posix.ntohl(val32);
			ptr= SEDE.deserialise_u16(ptr, out val16); // Groundspeed ( km/h * 10 )
			double gspeed = 0;
			if (val16 != 0xffff) {
				gspeed = Posix.ntohs(val16) / 36.0; // m/s
			}
			ptr= SEDE.deserialise_u16(ptr, out val16);  // COG Heading ( degree * 100 )
			double hdg = 0;
			if (val16 != 0xffff) {
				hdg = Posix.ntohs(val16) / 100.0; // deg
			}
			ptr= SEDE.deserialise_u16(ptr, out val16);
			int32 alt= (int32)Posix.ntohs(val16) - 1000; // m
			uint8 nsat = *ptr;
			CRSF.teledata.lat = lat / 1e7;
			CRSF.teledata.lon = lon / 1e7;
			CRSF.teledata.heading = (int)hdg;
			CRSF.teledata.alt = (int)alt;
			CRSF.teledata.nsat = nsat;
			CRSF.teledata.speed = (int)gspeed;
			if (nsat > 5)
				CRSF.teledata.fix = 3;
			else
				CRSF.teledata.fix = 1;

			MSP_RAW_GPS rg = MSP_RAW_GPS();
			rg.gps_fix = CRSF.teledata.fix;
			if(rg.gps_fix != 0) {
				last_gps = nticks;
			}
			flash_gps();

			rg.gps_numsat = nsat;
			rg.gps_lat = lat;
			rg.gps_lon = lon;
			rg.gps_altitude = (int16)alt;
			rg.gps_speed = (uint16)gspeed*100;
			rg.gps_ground_course = (uint16)hdg*10;
			double ddm;
			if(fakeoff.faking) {
				rg.gps_lat += (int32)(fakeoff.dlat*10000000);
				rg.gps_lon += (int32)(fakeoff.dlon*10000000);
			}

			gpsfix = (gpsinfo.update(rg, conf.dms, item_visible(DOCKLETS.GPS),
									 out ddm) != 0);

			MSP_ALTITUDE al = MSP_ALTITUDE();
			al.estalt = alt*100;
			al.vario =  calc_vario(alt*100);
			navstatus.set_altitude(al, item_visible(DOCKLETS.NAVSTATUS));
			vabox.update(item_visible(DOCKLETS.VBOX), al.vario);

			fbox.update(item_visible(DOCKLETS.FBOX));
			dbox.update(item_visible(DOCKLETS.DBOX));
			_nsats = rg.gps_numsat;

			if (gpsfix) {
				sat_coverage();
				if(armed == 1) {
					var spd = (double)(rg.gps_speed/100.0);
					update_odo(spd, ddm);
					if(have_home == false && (nsat > 5) &&
					   (lat != 0 && lon != 0) ) {
						wp0.lat = GPSInfo.lat;
						wp0.lon = GPSInfo.lon;
						sflags |=  NavStatus.SPK.GPS;
						want_special |= POSMODE.HOME;
						navstatus.cg_on();
					}

					if(pos_valid(GPSInfo.lat, GPSInfo.lon)) {
						last_gps = nticks;
						double dist,cse;
						Geo.csedist(GPSInfo.lat, GPSInfo.lon,
									home_pos.lat, home_pos.lon,
									out dist, out cse);
						if(dist < 256) {
							var cg = MSP_COMP_GPS();
							cg.range = (uint16)Math.lround(dist*1852);
							cg.direction = (int16)Math.lround(cse);
							navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
						}
					}
				}

				if(craft != null) {
					update_pos_info();
				}
				if(want_special != 0)
					process_pos_states(GPSInfo.lat,GPSInfo.lon, rg.gps_altitude, "CRSF");
			}
			break;
		case CRSF.BAT_ID:
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
			double volts = 0;
			if (val16 != 0xffff) {
				volts = Posix.ntohs(val16) / 10.0; // Volts
			}
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
			double amps = 0;
			if (val16 != 0xffff) {
				amps = Posix.ntohs(val16) / 10.0; // Amps
			}
			ptr = CRSF.deserialise_be_u24(ptr, out val32);
			uint32 capa = val32;
			//uint8 pctrem = *ptr; // Not used.
//			stdout.printf("MM: Battery %.1fV, %.1fA  Draw: %d mAh Remain %d\n", volts, amps, capa, pctrem);

			CRSF.teledata.volts = volts;
			curr.mah = capa;
			curr.centiA = (int16)amps*100;
			curr.ampsok = true;
			if (curr.centiA > odo.amps)
				odo.amps = curr.centiA;
			navstatus.current(curr, conf.smartport_fuel);
			crsf_analog();
			break;

		case CRSF.VARIO_ID:
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
//			stdout.printf("VARIO %d cm/s\n", (int16)val16);
			CRSF.teledata.vario = (int)Posix.ntohs(val16);
			break;
		case CRSF.ATTI_ID:
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Pitch radians *10000
			double pitch = 0;
			pitch = ((int16)Posix.ntohs(val16)) * CRSF.ATTITODEG;
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Roll radians *10000
			double roll = 0;
			roll = ((int16)Posix.ntohs(val16)) * CRSF.ATTITODEG;
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Roll radians *10000
			double yaw = 0;
			yaw = ((int16)Posix.ntohs(val16)) * CRSF.ATTITODEG;
//			yaw = ((yaw + 180) % 360);
//			stdout.printf("Pitch %.1f, Roll %.1f, Yaw %.1f\n", pitch, roll, yaw);
			CRSF.teledata.pitch = (int16)pitch;
			CRSF.teledata.roll = (int16)roll;
			CRSF.teledata.yaw = mhead = (int16)yaw ;
			LTM_AFRAME af = LTM_AFRAME();
			af.pitch = CRSF.teledata.pitch;
			af.roll = CRSF.teledata.roll;
			af.heading = mhead;
			navstatus.update_ltm_a(af, true);

			art_win.update(CRSF.teledata.roll*10, CRSF.teledata.pitch*10, item_visible(DOCKLETS.ARTHOR));
			break;
		case CRSF.FM_ID:
			bool c_armed = true;
			uint32 arm_flags = 0;
			uint64 mwflags = 0;
			uint8 ltmflags = 0;
			bool failsafe = false;
			string fm = (string)ptr;
//			stdout.printf("FM %s\n", (string)ptr );
			switch(fm) {
			case "AIR":
			case "ACRO":
// Ardupilot WTF ...
            case "QACRO":
				ltmflags = MSP.LTM.acro;
				break;

			case "!FS!":
				failsafe = true;
				break;

			case "MANU":
// Ardupilot WTF ...
            case "MAN":
				ltmflags = MSP.LTM.manual; // RTH
				break;

			case "RTH":
// Ardupilot WTF ...
            case "RTL":
            case "QRTL":
            case "LAND":
            case "QLAND":
            case "AUTORTL":
            case "SMRTRTL":
				ltmflags = MSP.LTM.rth; // RTH
				break;

			case "HOLD":
// Ardupilot WTF ...
            case "LOIT":
            case "CIRC":
            case "GUID":
            case "GUIDED":
            case "QLOIT":
            case "POSHLD":
				ltmflags = MSP.LTM.poshold; // PH
				break;

			case "CRUZ":
			case "CRSH":
// Ardupilot WTF ...
            case "CRUISE":
				ltmflags = MSP.LTM.cruise; // Cruise
				break;

			case "AH":
// Ardupilot WTF ...
            case "ALTHOLD":
				ltmflags = MSP.LTM.althold; // AltHold
				break;

			case "WP":
// Ardupilot WTF ...
            case "AUTO":
				ltmflags = MSP.LTM.waypoints;  // WP
				break;

			case "ANGL":
// Ardupilot WTF ...
            case "FBWA":
            case "STAB":
            case "TRAIN":
            case "TKOF":
            case "ATUNE":
            case "ADSB":
            case "THRML":
            case "L2QLND":
                ltmflags = MSP.LTM.angle; // Angle
				break;

			case "HOR":
// Ardupilot WTF ...
            case "FBWB":
            case "QSTAB":
            case "QHOV":
				ltmflags = MSP.LTM.horizon; // Horizon
				break;

// Ardupilot WTF ...
            case "ATUN":
            case "AVD_ADSB":
            case "BRAKE":
            case "DRFT":
            case "FLIP":
            case "FLOHOLD":
            case "FOLLOW":
            case "GUID_NOGPS":
            case "HELI_ARO":
            case "SPORT":
            case "SYSID":
            case "THROW":
            case "TRTLE":
            case "ZIGZAG":
				ltmflags = MSP.LTM.acro;
				break;

            default:
				c_armed = false;
				break;
			}
			if(xfailsafe != failsafe) {
				if(failsafe) {
					arm_flags |=  ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
					MWPLog.message("Failsafe asserted %ds\n", duration);
					map_show_warning("FAILSAFE");
				} else {
					MWPLog.message("Failsafe cleared %ds\n", duration);
					map_hide_warning();
				}
				xfailsafe = failsafe;
			}

			armed = (c_armed) ? 1 : 0;
			if(arm_flags != xarm_flags) {
				xarm_flags = arm_flags;
				if((arm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0) {
					arm_warn.show();
				} else {
					arm_warn.hide();
				}
			}

			if(ltmflags == MSP.LTM.angle)
				mwflags |= angle_mask;
			if(ltmflags == MSP.LTM.horizon)
				mwflags |= horz_mask;
			if(ltmflags == MSP.LTM.poshold)
				mwflags |= ph_mask;
			if(ltmflags == MSP.LTM.waypoints)
				mwflags |= wp_mask;
			if(ltmflags == MSP.LTM.rth || ltmflags == MSP.LTM.land)
				mwflags |= rth_mask;
			else
				mwflags = xbits; // don't know better

			var achg = armed_processing(mwflags,"CRSF");
			var xws = want_special;
			var mchg = (ltmflags != last_ltmf);
			if (mchg) {
				last_ltmf = ltmflags;
				if(ltmflags == MSP.LTM.poshold)
					want_special |= POSMODE.PH;
				else if(ltmflags == MSP.LTM.waypoints) {
					want_special |= POSMODE.WP;
					if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
						NavStatus.nm_pts = last_wp_pts;
				} else if(ltmflags == MSP.LTM.rth)
					want_special |= POSMODE.RTH;
				else if(ltmflags == MSP.LTM.althold)
					want_special |= POSMODE.ALTH;
				else if(ltmflags == MSP.LTM.cruise)
					want_special |= POSMODE.CRUISE;
				else if(ltmflags != MSP.LTM.land) {
					if(craft != null)
						craft.set_normal();
				}
				var lmstr = MSP.ltm_mode(ltmflags);
				fmodelab.set_label(lmstr);
				MWPLog.message("New CRSF Mode %s (%d) %d %ds %f %f %x %x\n",
							   lmstr, ltmflags, armed, duration, xlat, xlon,
							   xws, want_special);
			}

			if(achg || mchg)
				update_mss_state(ltmflags);

			if(wp0.lat == 0.0 && wp0.lon == 0.0) {
				if(CRSF.teledata.fix > 1) {
					wp0.lat = CRSF.teledata.lat;
					wp0.lon = CRSF.teledata.lon;
				}
			}
			if(want_special != 0 /* && have_home*/)
				process_pos_states(xlat,xlon, 0, "CRSF status");
			break;

		case CRSF.LINKSTATS_ID:
			if(ptr[2] == 0) {
				CRSF.teledata.rssi = (ptr[0] > ptr[1]) ? ptr[0] : ptr[1];
				CRSF.teledata.rssi = 1023*CRSF.teledata.rssi/255;
				radstatus.set_title(0);
			} else {
				CRSF.teledata.rssi = 1023*ptr[2]/100;
				radstatus.set_title(1);
			}
			crsf_analog();
			break;

		case CRSF.DEV_ID:
			if((debug_flags & DEBUG_FLAGS.SERIAL) != DEBUG_FLAGS.NONE) {
				MWPLog.message("CRSF-DEV %s\n", (string)(ptr+5));
			}
			break;
		default:
			break;
		}
	}

	private void ProcessFlysky(uint8[] raw) {
        FLYSKY.Telem t;
		if(FLYSKY.decode(raw, out t)) {
			processFlysky_telem(t);
		}
	}

	private void processFlysky_telem(FLYSKY.Telem t) {
		if ((t.mask & (1 << FLYSKY.Func.VBAT)) != 0) {
			MSP_ANALOG an = MSP_ANALOG();
			an.rssi = 4*(uint16)t.rssi;
			an.vbat = (uint8)(t.vbat * 10);
			an.amps = (uint16)t.curr*100;
			process_msp_analog(an);
		}
		if ((t.mask & (1 << FLYSKY.Func.LAT0|FLYSKY.Func.LAT1|FLYSKY.Func.LON0|FLYSKY.Func.LON1|FLYSKY.Func.STATUS)) != 0) {
			int hdop = (t.status % 100) / 10;
			int nsat = (t.status / 1000);
			hdop = hdop*10 + 1;
			int fix = 0;
			bool home = false;

			int ifix = (t.status % 1000) / 100;
			if (ifix > 4) {
				home = true;
				ifix =- 5;
			}
			fix = ifix & 3;

			MSP_RAW_GPS rg = MSP_RAW_GPS();
			rg.gps_fix =(uint8) fix;
			if(rg.gps_fix != 0) {
				last_gps = nticks;
			}
			flash_gps();

			rg.gps_numsat = (uint8)nsat;
			rg.gps_lat = t.ilat;
			rg.gps_lon = t.ilon;
			rg.gps_altitude = (int16)t.alt;
			rg.gps_speed = (uint16)t.speed*100;
			rg.gps_ground_course = (uint16)t.cog*10;
			double ddm;
			if(fakeoff.faking) {
				rg.gps_lat += (int32)(fakeoff.dlat*10000000);
				rg.gps_lon += (int32)(fakeoff.dlon*10000000);
			}

			mhead = (int16)t.heading;
			LTM_AFRAME af = LTM_AFRAME();
			af.pitch = 0;
			af.roll = 0;
			af.heading = mhead;
			navstatus.update_ltm_a(af, true);

			gpsfix = (gpsinfo.update(rg, conf.dms, item_visible(DOCKLETS.GPS),
									 out ddm) != 0);

			fbox.update(item_visible(DOCKLETS.FBOX));
			dbox.update(item_visible(DOCKLETS.DBOX));
			_nsats = rg.gps_numsat;

			if (gpsfix) {
				sat_coverage();
				if(armed == 1) {
					var spd = (double)(rg.gps_speed/100.0);
					update_odo(spd, ddm);
					if(have_home == false && (nsat > 5) &&
					   (t.ilat != 0 && t.ilon != 0) ) {
						wp0.lat = GPSInfo.lat;
						wp0.lon = GPSInfo.lon;
						sflags |=  NavStatus.SPK.GPS;
						want_special |= POSMODE.HOME;
						navstatus.cg_on();
					}
				}

				if(craft != null) {
					update_pos_info();
				}
				if(want_special != 0)
					process_pos_states(GPSInfo.lat,GPSInfo.lon, rg.gps_altitude, "Flysky");
				rhdop = (uint16)hdop*100;
				gpsinfo.set_hdop(hdop);
			}

			if((t.mask & (1 << FLYSKY.Func.HOMEDIRN|FLYSKY.Func.HOMEDIST)) != 0) {
				var cg = MSP_COMP_GPS();
				cg.range = (uint16)t.homedist;
				cg.direction = (int16)t.homedirn;
				navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
				update_odo(t.speed, ddm);
			}
		}

		if ((t.mask & (1 << FLYSKY.Func.STATUS)) != 0) {
			int mode = t.status % 10;
			int ifix = (t.status % 1000) / 100;
			bool fl_armed = (ifix > 4) ? true : false;
			bool failsafe = false;
			uint32 arm_flags = 0;
			uint64 mwflags = 0;
			uint8 ltmflags = 0;

			switch(mode) {
			case 0:
				ltmflags = MSP.LTM.manual;
				break;
			case 1:
				ltmflags = MSP.LTM.acro;
				break;
			case 2:
				ltmflags = MSP.LTM.horizon;
				break;
			case 3:
				ltmflags = MSP.LTM.angle;
				break;
			case 4:
				ltmflags = MSP.LTM.waypoints;
				break;
			case 5:
				ltmflags = MSP.LTM.althold;
				break;
			case 6:
				ltmflags = MSP.LTM.poshold;
				break;
			case 7:
				ltmflags = MSP.LTM.rth;
				break;
			case 8:
				ltmflags = MSP.LTM.launch;
				break;
			case 9:
				failsafe = true;
				break;
			}
			if(xfailsafe != failsafe) {
				if(failsafe) {
					arm_flags |=  ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
					MWPLog.message("Failsafe asserted %ds\n", duration);
					map_show_warning("FAILSAFE");
				} else {
					MWPLog.message("Failsafe cleared %ds\n", duration);
					map_hide_warning();
				}
				xfailsafe = failsafe;
			}

			armed = (fl_armed) ? 1 : 0;
			if(arm_flags != xarm_flags) {
				xarm_flags = arm_flags;
				if((arm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0) {
					arm_warn.show();
				} else {
					arm_warn.hide();
				}
			}

			if(ltmflags == MSP.LTM.angle)
				mwflags |= angle_mask;
			if(ltmflags == MSP.LTM.horizon)
				mwflags |= horz_mask;
			if(ltmflags == MSP.LTM.poshold)
				mwflags |= ph_mask;
			if(ltmflags == MSP.LTM.waypoints)
				mwflags |= wp_mask;
			if(ltmflags == MSP.LTM.rth || ltmflags == MSP.LTM.land)
				mwflags |= rth_mask;
			else
				mwflags = xbits; // don't know better

			var achg = armed_processing(mwflags,"Flysky");
			var xws = want_special;
			var mchg = (ltmflags != last_ltmf);
			if (mchg) {
				last_ltmf = ltmflags;
				if(ltmflags == MSP.LTM.poshold)
					want_special |= POSMODE.PH;
				else if(ltmflags == MSP.LTM.waypoints) {
					want_special |= POSMODE.WP;
					if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
						NavStatus.nm_pts = last_wp_pts;
				}
				else if(ltmflags == MSP.LTM.rth)
					want_special |= POSMODE.RTH;
				else if(ltmflags == MSP.LTM.althold)
					want_special |= POSMODE.ALTH;
				else if(ltmflags == MSP.LTM.cruise)
					want_special |= POSMODE.CRUISE;
				else if (ltmflags == MSP.LTM.undefined)
					want_special |= POSMODE.UNDEF;
				else if(ltmflags != MSP.LTM.land) {
					if(craft != null)
						craft.set_normal();
				}
				var lmstr = MSP.ltm_mode(ltmflags);
				MWPLog.message("New Flysky Mode %s (%d) %d %ds %f %f %x %x\n",
							   lmstr, ltmflags, armed, duration, xlat, xlon,
							   xws, want_special);
				fmodelab.set_label(lmstr);
			}

			if(achg || mchg)
				update_mss_state(ltmflags);

			if(wp0.lat == 0.0 && wp0.lon == 0.0) {
				if(CRSF.teledata.fix > 1) {
					wp0.lat = CRSF.teledata.lat;
					wp0.lon = CRSF.teledata.lon;
				}
			}
			if(want_special != 0 /* && have_home*/)
				process_pos_states(xlat,xlon, 0, "Flysky");
		}
	}

    private void process_sport_message (SportDev.FrID id, uint32 val) {
		if(!SportDev.active) {
			verlab.label = verlab.tooltip_text = "S-Port telemetry";
			SportDev.active = true;
			xnopoll = nopoll;
			nopoll = true;
			serstate = SERSTATE.TELEM;
		}

        double r;
        if(Logger.is_logging)
            Logger.log_time();

        lastrx = lastok = nticks;
        if(rxerr) {
            set_error_status(null);
            rxerr=false;
        }

        switch(id) {
            case SportDev.FrID.VFAS_ID:
                if (val /100  < 80) {
                    SportDev.volts = val / 100.0;
                    sflags |=  NavStatus.SPK.Volts;
                }
                break;
            case SportDev.FrID.GPS_LONG_LATI_ID:
                int32 ipos;
                uint8 lorl = sport_parse_lat_lon (val, out ipos);
                if (lorl == 0) {
                    SportDev.lat = ipos;
				} else {
                    SportDev.lon = ipos;
                    init_craft_icon();
                    MSP_ALTITUDE al = MSP_ALTITUDE();
                    al.estalt = SportDev.alt;
                    al.vario = SportDev.vario;
                    navstatus.set_altitude(al, item_visible(DOCKLETS.NAVSTATUS));
                    vabox.update(item_visible(DOCKLETS.VBOX), al.vario);
                    double ddm;
                    gpsinfo.update_sport(conf.dms, item_visible(DOCKLETS.GPS), out ddm);

                    if(SportDev.fix > 0) {
                        sat_coverage();
                        if(armed != 0) {
                            if(have_home) {
                                if(_nsats >= msats) {
                                    if(pos_valid(GPSInfo.lat, GPSInfo.lon)) {
										last_gps = nticks;
                                        double dist,cse;
                                        Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                                                    home_pos.lat, home_pos.lon,
                                                    out dist, out cse);
                                        if(dist < 256) {
                                            var cg = MSP_COMP_GPS();
                                            cg.range = (uint16)Math.lround(dist*1852);
                                            cg.direction = (int16)Math.lround(cse);
                                            navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
                                            update_odo(SportDev.spd, ddm);
                                            SportDev.range =  cg.range;
                                        }
                                    }
                                }
                            } else {
                                if(no_ofix == 10) {
                                    MWPLog.message("No home position yet\n");
                                }
                            }
                        }

                        if(craft != null && SportDev.fix > 0 && SportDev.sats >= msats) {
                            update_pos_info();
                        }

                        if(want_special != 0)
                            process_pos_states(GPSInfo.lat, GPSInfo.lon, SportDev.alt/100.0, "Sport");
                    }
                    fbox.update(item_visible(DOCKLETS.FBOX));
                    dbox.update(item_visible(DOCKLETS.DBOX));
                }
                break;
            case SportDev.FrID.GPS_ALT_ID:
                r =((int)val) / 100.0;
                SportDev.galt = r;
                break;
            case SportDev.FrID.GPS_SPEED_ID:
                r = ((val/1000.0)*0.51444444);
                SportDev.spd = r;
                break;
            case SportDev.FrID.GPS_COURS_ID:
                r = val / 100.0;
                SportDev.cse = r;
                navstatus.sport_hdr(r);
                break;
            case SportDev.FrID.ADC2_ID: // AKA HDOP
                rhdop = (uint16)((val &0xff)*10);
                SportDev.rhdop = rhdop;
                SportDev.flags |= 1;
                break;
            case SportDev.FrID.ALT_ID:
                r = (int)val / 100.0;
                SportDev.alt = (int)val;
                sflags |=  NavStatus.SPK.ELEV;
                break;
            case SportDev.FrID.T1_ID: // flight modes
                uint ival = val;
                uint32 arm_flags = 0;
                uint64 mwflags = 0;
                uint8 ltmflags = 0;
                bool failsafe = false;

                var modeU = ival % 10;
                var modeT = (ival % 100) / 10;
                var modeH = (ival % 1000) / 100;
                var modeK = (ival % 10000) / 1000;
                var modeJ = ival / 10000;

                if((modeU & 1) == 0)
                    arm_flags |=  ARMFLAGS.ARMING_DISABLED_OTHER;
                if ((modeU & 4) == 4) { // armed
                    mwflags = arm_mask;
                    armed = 1;
                    dac = 0;
                } else {
                    dac++;
                    if(dac == 1 && armed != 0) {
                        MWPLog.message("Assumed disarm from SPORT %ds\n", duration);
                        mwflags = 0;
                        armed = 0;
                        init_have_home();
                    }
                }

                if(modeT == 0)
                    ltmflags = MSP.LTM.acro; // Acro
                if (modeT == 1)
                    ltmflags = MSP.LTM.angle; // Angle
                else if (modeT == 2)
                    ltmflags = MSP.LTM.horizon; // Horizon
                else if(modeT == 4)
                    ltmflags = MSP.LTM.acro; // Acro

                if((modeH & 2) == 2)
                    ltmflags = MSP.LTM.althold; // AltHold
                if((modeH & 4) == 4)
                    ltmflags = MSP.LTM.poshold; // PH

                if(modeK == 1)
                    ltmflags = MSP.LTM.rth; // RTH
                if(modeK == 2)
                    ltmflags = MSP.LTM.waypoints;  // WP
//                            if(modeK == 4) ltmflags = 11;
                if(modeK == 8)
                    ltmflags = MSP.LTM.cruise; // Cruise

                    // if(modeK == 2) emode = "AUTOTUNE";
                failsafe = (modeJ == 4);
                if(xfailsafe != failsafe) {
                    if(failsafe) {
                        arm_flags |=  ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
                        MWPLog.message("Failsafe asserted %ds\n", duration);
                        map_show_warning("FAILSAFE");
                    } else {
                        MWPLog.message("Failsafe cleared %ds\n", duration);
                        map_hide_warning();
                    }
                    xfailsafe = failsafe;
                }

                if(arm_flags != xarm_flags) {
                    xarm_flags = arm_flags;
                   if((arm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0) {
                        arm_warn.show();
                    } else {
                        arm_warn.hide();
                    }
                }

                if(ltmflags == MSP.LTM.angle)
                    mwflags |= angle_mask;
                if(ltmflags == MSP.LTM.horizon)
                    mwflags |= horz_mask;
                if(ltmflags == MSP.LTM.poshold)
                    mwflags |= ph_mask;
                if(ltmflags == MSP.LTM.waypoints)
                    mwflags |= wp_mask;
                if(ltmflags == MSP.LTM.rth || ltmflags == MSP.LTM.land)
                    mwflags |= rth_mask;
                else
                    mwflags = xbits; // don't know better

                var achg = armed_processing(mwflags,"Sport");
                var xws = want_special;
                var mchg = (ltmflags != last_ltmf);
                if (mchg) {
                    last_ltmf = ltmflags;
                    if(ltmflags == MSP.LTM.poshold)
                        want_special |= POSMODE.PH;
                    else if(ltmflags == MSP.LTM.waypoints) {
                        want_special |= POSMODE.WP;
                        if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
                            NavStatus.nm_pts = last_wp_pts;
                    }
                    else if(ltmflags == MSP.LTM.rth)
                        want_special |= POSMODE.RTH;
                    else if(ltmflags == MSP.LTM.althold)
                        want_special |= POSMODE.ALTH;
                    else if(ltmflags == MSP.LTM.cruise)
                        want_special |= POSMODE.CRUISE;
                    else if(ltmflags != MSP.LTM.land) {
                        if(craft != null)
                            craft.set_normal();
                    }
                    var lmstr = MSP.ltm_mode(ltmflags);
                    MWPLog.message("New SPort/LTM Mode %s (%d) %d %ds %f %f %x %x\n",
                                   lmstr, ltmflags, armed, duration, xlat, xlon,
                                   xws, want_special);
                    fmodelab.set_label(lmstr);
                }

                if(achg || mchg)
                    update_mss_state(ltmflags);

                if(want_special != 0 /* && have_home*/)
                    process_pos_states(xlat,xlon, 0, "SPort status");

                LTM_SFRAME sf = LTM_SFRAME ();
                sf.vbat = (uint16)(SportDev.volts*1000);
                sf.flags = ((failsafe) ? 2 : 0) | (armed & 1) | (ltmflags << 2);
                sf.vcurr = (conf.smartport_fuel == 2) ? (uint16)curr.mah : 0;
                sf.rssi = (uint8)(SportDev.rssi * 255/ 1023);
                sf.airspeed = 0;
                navstatus.update_ltm_s(sf, item_visible(DOCKLETS.NAVSTATUS),true);
                break;

            case SportDev.FrID.T2_ID: // GPS info
                uint8 ifix = 0;
                _nsats = (uint8)(val % 100);
                uint16 hdp;
                hdp = (uint16)(val % 1000)/100;
                if (SportDev.flags == 0) // prefer FR_ID_ADC2_ID
                    SportDev.rhdop = rhdop = 550 - (hdp * 50);

                uint8 gfix = (uint8)(val /1000);
                if ((gfix & 1) == 1)
                    ifix = 3;
                if ((gfix & 2) == 2) {
                    if(have_home == false && armed != 0) {
                        if(home_changed(GPSInfo.lat, GPSInfo.lon)) {
                            if(SportDev.fix == 0) {
                                no_ofix++;
                            } else {
                                navstatus.cg_on();
                                sflags |=  NavStatus.SPK.GPS;
                                want_special |= POSMODE.HOME;
                                process_pos_states(GPSInfo.lat, GPSInfo.lon, 0.0, "SPort");
                            }
                        }
                    }
                }
                if ((gfix & 4) == 4) {
                    if (SportDev.range < 500) {
                        MWPLog.message("SPORT: %s set home: changed home position %f %f\n",
                                       id.to_string(), GPSInfo.lat, GPSInfo.lon);
                        home_changed(GPSInfo.lat, GPSInfo.lon);
                        want_special |= POSMODE.HOME;
                        process_pos_states(GPSInfo.lat, GPSInfo.lon, 0.0, "SPort");
                    } else {
                        MWPLog.message("SPORT: %s Ignoring (bogus?) set home, range > 500m: requested home position %f %f\n", id.to_string(), GPSInfo.lat, GPSInfo.lon);
                    }
                }

                if((_nsats == 0 && nsats != 0) || (nsats == 0 && _nsats != 0)) {
                    nsats = _nsats;
                    navstatus.sats(_nsats, true);
                }
                SportDev.sats = _nsats;
                SportDev.fix = ifix;
                flash_gps();
                last_gps = nticks;
                break;
            case SportDev.FrID.RSSI_ID:
                SportDev.rssi = (uint16)((val&0xff)*1023/100);
                MSP_ANALOG an = MSP_ANALOG();
                an.rssi = SportDev.rssi;
                an.vbat = (uint8)(SportDev.volts * 10);

                an.powermetersum = (conf.smartport_fuel == 2 )? (uint16)curr.mah :0;
                an.amps = curr.centiA;
                process_msp_analog(an);
                break;
            case SportDev.FrID.PITCH:
            case SportDev.FrID.ROLL:
                if (id == SportDev.FrID.ROLL)
                    SportDev.roll = (int16)val;
                else
                    SportDev.pitch = (int16)val;

                LTM_AFRAME af = LTM_AFRAME();
                af.pitch = SportDev.pitch;
                af.roll = SportDev.roll;
                af.heading = mhead = (int16) SportDev.cse;
                navstatus.update_ltm_a(af, true);
                art_win.update(af.roll*10, af.pitch*10, item_visible(DOCKLETS.ARTHOR));
                if(Logger.is_logging)
                    Logger.attitude((double)SportDev.pitch, (double)SportDev.roll, (int)mhead);
                break;

            case SportDev.FrID.HOME_DIST:
                int diff = (int)(SportDev.range - val);
                if(SportDev.range > 100 && (diff * 100 / SportDev.range) > 9)
                    MWPLog.message("%s %um (mwp: %u, diff: %d)\n", id.to_string(), val, SportDev.range, diff);
                break;

            case SportDev.FrID.CURR_ID:
                if((val / 10) < 999) {
                    curr.ampsok = true;
                    curr.centiA =  (uint16)(val * 10);
                    if (curr.centiA > odo.amps)
                        odo.amps = curr.centiA;
                    navstatus.current(curr, conf.smartport_fuel);
                }
                break;
            case SportDev.FrID.ACCX_ID:
                SportDev.ax = ((int)val) / 100.0;
                break;
            case SportDev.FrID.ACCY_ID:
                SportDev.ay = ((int)val) / 100.0;
                break;
            case SportDev.FrID.ACCZ_ID:
                SportDev.az = ((int)val) / 100.0;
                SportDev.pitch = -(int16)(180.0 * Math.atan2 (SportDev.ax, Math.sqrt(SportDev.ay*SportDev.ay + SportDev.az*SportDev.az))/Math.PI);
                SportDev.roll  = (int16)(180.0 * Math.atan2 (SportDev.ay, Math.sqrt(SportDev.ax*SportDev.ax + SportDev.az*SportDev.az))/Math.PI);
                art_win.update(SportDev.roll*10, SportDev.pitch*10, item_visible(DOCKLETS.ARTHOR));
                if(Logger.is_logging)
                    Logger.attitude((double)SportDev.pitch, (double)SportDev.roll, (int16) SportDev.cse);
                break;

            case SportDev.FrID.VARIO_ID:
                SportDev.vario = (int16)((int) val / 10);
                break;

            case SportDev.FrID.FUEL_ID:
                switch (conf.smartport_fuel) {
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

    private void update_mss_state(uint8 fmode) {
        MwpServer.State s = MwpServer.State.UNDEFINED;
        if(armed == 0)
            s = MwpServer.State.DISARMED;
        else {
            switch(fmode) {
			case 0:
				s = MwpServer.State.MANUAL;
				break;
			case 1:
			case 4:
				s = MwpServer.State.ACRO;
				break;
			case 2:
				s = MwpServer.State.ANGLE;
				break;
			case 3:
				s = MwpServer.State.HORIZON;
				break;
			case 8:
				s = MwpServer.State.ALTHOLD;
				break;
			case 9:
				s = MwpServer.State.POSHOLD;
				break;
			case 10:
				s = MwpServer.State.WP;
				break;
			case 11:
				s = MwpServer.State.HEADFREE;
				break;
			case 13:
				s = MwpServer.State.RTH;
				break;
			case 15:
				s = MwpServer.State.RTH;
				break;
			case 18:
				s = MwpServer.State.CRUISE;
				break;
			case 20:
				s = MwpServer.State.LAUNCH;
				break;
			case 21:
				s = MwpServer.State.AUTOTUNE;
				break;
            }
        }
        if(s != mss.m_state) {
            mss.m_state = s;
            mss.state_changed(s);
        }
    }

    private bool clip_location(bool fmt) {
        int mx,my;
        Gdk.Display display = Gdk.Display.get_default ();
        Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
        var seat = display.get_default_seat();
        var ptr = seat.get_pointer();
        embed.get_window().get_device_position(ptr, out mx, out my, null);
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

    private void hard_display_reset(bool cm = false) {
        if(cm) {
            clear_mission();
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
        if(craft != null) {
            craft.remove_marker();
            markers.remove_rings(view);
        }
        set_error_status(null);
        xsensor = 0;
        clear_sensor_array();
        remove_all_kml();
    }

    private void key_recentre(uint key) {
        var bb = view.get_bounding_box();
        var x = view.get_center_longitude();
        var y = view.get_center_latitude();
        switch (key) {
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

    private void acquire_bus() {
        Bus.own_name (BusType.SESSION, "org.mwptools.mwp", BusNameOwnerFlags.NONE,
                      on_bus_aquired,
                      () => {},
                      () => {
                          stderr.printf ("Could not aquire name\n");
                      });
    }

    private void on_bus_aquired (DBusConnection conn) {
        try {
            conn.register_object ("/org/mwptools/mwp",
                                  (mss = new MwpServer ()));
        } catch (IOError e) {
            stderr.printf ("Could not register service\n");
        }

        mss.i__set_mission.connect((s) => {
                Mission? ms = null;
                unichar c = s.get_char(0);

                if(c == '<') {
                    msx = XmlIO.read_xml_string(s);
				} else
                    msx = JsonIO.from_json(s);

				if(msx.length > 0) {
					ms = msx[0];
					instantiate_mission(ms);
				}
                return (ms != null) ? ms.npoints : 0;
            });

        mss.i__load_mission.connect((s) => {
                Mission ms;
                ms = open_mission_file(s);
                if(ms != null)
                    instantiate_mission(ms);
                return (ms != null) ? ms.npoints : 0;
            });

        mss.i__load_mwp_log.connect((s) => {
                run_replay(s, true, Player.MWP);
            });

        mss.i__load_blackbox.connect((s) => {
                replay_bbox(true, s);
            });

        mss.i__clear_mission.connect(() => {
                clear_mission();
                NavStatus.have_rth = false;
                NavStatus.nm_pts = 0;
            });

        mss.i__get_devices.connect(() => {
                int idx;
                mss.device_names = list_combo(dev_entry);
                idx =(msp.available) ? dev_entry.active : -1;
                return idx;
            });

        mss.i__upload_mission.connect((e) => {
                var flag = WPDL.CALLBACK;
                flag |= ((e) ? WPDL.SAVE_EEPROM : 0);
                upload_mm (-1, flag);
            });

        mss.i__connect_device.connect((s) => {
                int n = append_combo(dev_entry, s);
                if(n == -1)
                    return false;
                dev_entry.active = n;
                connect_serial();
                return msp.available;
            });

    }

    private void upload_callback(int pts) {
        wpmgr.wp_flag &= ~WPDL.CALLBACK;
        mss.nwpts = pts;
            // must use Idle.add as we may not otherwise hit the mainloop
        Idle.add(() => { mss.callback(); return false; });
    }

    private void get_map_size() {
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

    private bool get_primary_size(ref Gdk.Rectangle rect) {
        bool ret = true;

        Gdk.Display dp = Gdk.Display.get_default();
        var mon = dp.get_monitor(0);
        if(mon != null)
            rect = mon.get_geometry();
        else
            ret = false;
        return ret;
    }

    public void build_serial_combo() {
        dev_entry.remove_all ();
        foreach (var s in devman.get_serial_devices()) {
			prepend_combo(dev_entry, s);
		}

        foreach(string a in conf.devices) {
            dev_entry.append_text(a);
        }

        foreach (var s in devman.get_bt_serial_devices()) {
			append_combo(dev_entry, s);
		}
    }

    private string?[] list_combo(Gtk.ComboBoxText cbtx, int id=0) {
        string[] items={};
        var m = cbtx.get_model();
        Gtk.TreeIter iter;
        bool next;

        for(next = m.get_iter_first(out iter); next; next = m.iter_next(ref iter)) {
            GLib.Value cell;
            m.get_value (iter, id, out cell);
            items += (string)cell;
        }
        return items;
    }

    private int find_combo(Gtk.ComboBoxText cbtx, string s, int id=0) {
        var m = cbtx.get_model();
        Gtk.TreeIter iter;
        int i,n = -1;
        bool next;

        for(i = 0, next = m.get_iter_first(out iter); next; next = m.iter_next(ref iter), i++) {
            GLib.Value cell;
            m.get_value (iter, id, out cell);
            string cs = (string)cell;

            bool has_s = cs.contains(" ");

            if((has_s && ((string)cell).has_prefix(s)) || ((string)cell == s)) {
                n = i;
                break;
            }
        }
        return n;
    }

    private void check_pref_dev() {
        var dstr = Environment.get_variable("MWP_PREF_DEVICE");
        if (dstr != null) {
            var npref = find_combo(dev_entry, dstr);
            if(npref != -1)
                dev_entry.active = npref;
        }
    }

	private bool lookup_radar(string s) {
		foreach (var r in radardevs) {
			if (r.name == s) {
				MWPLog.message("Found radar %s\n", s);
				return true;
			}
		}
		return false;
	}

    private int append_combo(Gtk.ComboBoxText cbtx, string s) {
		if(lookup_radar(s))
            return -1;

		if(s == forward_device)
            return -1;

        var n = find_combo(cbtx, s);
        if (n == -1) {
            cbtx.append_text(s);
            n = 0;
        }

        check_pref_dev();

        if(cbtx.active == -1)
            cbtx.active = 0;

        ttrk.add(s);
        return n;
    }

    private void prepend_combo(Gtk.ComboBoxText cbtx, string s) {
		if(lookup_radar(s))
            return;

        if(s == forward_device)
            return;

        var n = find_combo(cbtx, s);
        if (n == -1) {
            cbtx.prepend_text(s);
            cbtx.active = 0;
        } else {
            cbtx.active = n;
		}
        ttrk.add(s);
    }

    private void remove_combo(Gtk.ComboBoxText cbtx,string s) {
        ttrk.remove(s);
        foreach(string a in conf.devices) {
			if (a == s)
                return;
		}

		var n = find_combo(cbtx, s);
        if (n != -1) {
            cbtx.remove(n);
            cbtx.active = 0;
        }
    }

    private bool view_delta_diff(double f0, double f1) {
        double delta;
        delta = 0.0000025 * Math.pow(2, (20-view.zoom_level));
        var res = (Math.fabs(f0-f1) > delta);
        return res;
    }

    private bool map_moved() {
        var iy =  view.get_center_latitude();
        var ix =  view.get_center_longitude();
        var res = (view_delta_diff(lx,ix) || view_delta_diff(ly,iy));
        ly=iy;
        lx=ix;
        return  res;
    }

    private void setup_buttons() {
        embed.button_release_event.connect((evt) => {
                if(evt.button == 3)
                    if(!ls.pop_marker_menu(evt))
                        safehomed.pop_menu(evt);
                return false;
            });

        view.button_release_event.connect((evt) => {
                bool ret = false;
                if (evt.button == 1 && wp_edit && !mlayer.is_active()) {
                    if(!map_moved()) {
                        insert_new_wp(evt.x, evt.y);
                        ret = true;
                    }
                } else {
                    anim_cb(false);
                }
                return ret;
            });

        view.motion_event.connect ((evt) => {
                if (!pos_is_centre) {
                    var lon = view.x_to_longitude (evt.x);
                    var lat = view.y_to_latitude (evt.y);
                    poslabel.label = PosFormat.pos(lat,lon,conf.dms);
                }
                return false;
            });

    }

    public void update_pointer_pos(double lat, double lon) {
        if (!pos_is_centre) {
            poslabel.label = PosFormat.pos(lat,lon,conf.dms);
        }
    }

    private void insert_new_wp(float x, float y) {
        var lon = view.x_to_longitude (x);
        var lat = view.y_to_latitude (y);
        ls.insert_item(MSP.Action.WAYPOINT, lat, lon);
        ls.calc_mission();
    }

    private void parse_rc_mav(string s, Craft.Special ptype) {
        var parts = s.split(":");
        if(parts.length == 3) {
            mavposdef += MavPOSDef() { minval=(uint16)int.parse(parts[1]),
                maxval=(uint16)int.parse(parts[2]),
                ptype = ptype,
                chan = (uint8)int.parse(parts[0]), set =0};
        }
    }

    private void toggle_full_screen() {
        if(wdw_state == true) {
            window.unfullscreen();
        } else {
            window.fullscreen();
        }
        mwpdh.transient(window, !wdw_state);
    }

    private bool try_connect() {
        if(autocon) {
            if(!msp.available)
                connect_serial();
            Timeout.add_seconds(5, () => { return try_connect(); });
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    }

    private void set_error_status(string? e) {
        if(e != null) {
            MWPLog.message("message => %s\n", e);
            statusbar.push(context_id, e);
            play_alarm_sound(MWPAlert.GENERAL);
        } else {
            statusbar.push(context_id, "");
        }
    }

    private void msg_poller() {
        if(serstate == SERSTATE.POLLER) {
            lastp.start();
            send_poll();
        }
    }

    private bool pos_valid(double lat, double lon) {
        bool vpos;
        if(have_home) {
            if( ((Math.fabs(lat - xlat) < 0.25) &&
                 (Math.fabs(lon - xlon) < 0.25)) || (xlon == 0 && xlat == 0)) {
                vpos = true;
                xlat = lat;
                xlon = lon;
            } else {
                vpos = false;
                if(xlat != 0.0 && xlon != 0.0)
                    MWPLog.message("Ignore bogus %f %f (%f %f)\n",
                                   lat, lon, xlat, xlon);
            }
        } else
            vpos = true;
//        MWPLog.message("pv %s %s %f %f (%f %f)\n",
//                       have_home.to_string(), vpos.to_string(), lat, lon, xlat, xlon);
        return vpos;
    }

    private void resend_last() {
        if(msp.available) {
            if(lastmsg.cmd != MSP.Cmds.INVALID) {
//                MWPLog.message("resend %s\n", lastmsg.cmd.o_string());
                msp.send_command((uint16)lastmsg.cmd, lastmsg.data, lastmsg.len);
            } else
                run_queue();
        }
    }

    private void  run_queue() {
        if(msp.available && !mq.is_empty()) {
            lastmsg = mq.pop_head();
//            MWPLog.message("send %s\n", lastmsg.cmd.to_string());
            msp.send_command((uint16)lastmsg.cmd, lastmsg.data, lastmsg.len);
        }
    }

    private void start_poll_timer() {
        var lmin = 0;

        Timeout.add(TIMINTVL, () => {
                nticks++;
                if(msp.available) {
                    if(serstate != SERSTATE.NONE) {
                        var tlimit = conf.polltimeout / TIMINTVL;
						if ((lastmsg.cmd == MSP.Cmds.WP_MISSION_SAVE) ||
							lastmsg.cmd == MSP.Cmds.EEPROM_WRITE) {
							tlimit *= 3;
						}
						if((serstate == SERSTATE.POLLER ||
                            serstate == SERSTATE.TELEM) &&
                           (nticks - lastrx) > NODATAINTVL) {
                            if(rxerr == false) {
                                set_error_status("No data for 5s");
                                rxerr=true;
                            }
                        }

                        if(serstate != SERSTATE.TELEM) {
// Probably takes a minute to change the LIPO
                            if(serstate == SERSTATE.POLLER && nticks - lastrx > RESTARTINTVL) {
                                serstate = SERSTATE.NONE;
                                MWPLog.message("Restart poll loop\n");
                                init_state();
                                init_sstats();
                                init_have_home();
                                serstate = SERSTATE.NORMAL;
                                queue_cmd(MSP.Cmds.IDENT,null,0);
                                if(inhibit_cookie != 0) {
                                    uninhibit(inhibit_cookie);
                                    inhibit_cookie = 0;
                                    dtnotify.send_notification("mwp", "Unhibit screen/idle/suspend");
                                    MWPLog.message("Not managing screen / power settings\n");
                                }
                                run_queue();
                            } else if ((nticks - lastok) > tlimit ) {
                                telstats.toc++;
                                string res;
                                if(lastmsg.cmd != MSP.Cmds.INVALID) {
                                    res = lastmsg.cmd.to_string();
                                } else {
                                    res = "%d".printf(tcycle);
								}
                                if(nopoll == false)
                                    MWPLog.message("MSP Timeout %u %u %u (%s %s)\n",
												   nticks, lastok, lastrx, res, serstate.to_string());
                                lastok = nticks;
                                tcycle = 0;
                                resend_last();
                            }
                        } else {
                            if(armed != 0 && msp.available &&
                               gpsintvl != 0 && last_gps != 0) {
                                if (nticks - last_gps > gpsintvl) {
                                    if(replayer == Player.NONE)
                                        play_alarm_sound(MWPAlert.SAT);
                                    if(replay_paused == false)
                                        MWPLog.message("GPS stalled\n");
                                    gpslab.label = "<span foreground = \"red\">⬤</span>";
                                    last_gps = nticks;
                                }
                            }

                            if(serstate == SERSTATE.TELEM && nopoll == false &&
                               last_tm > 0 &&
                               ((nticks - last_tm) > MAVINTVL)
                               && msp.available && replayer == Player.NONE) {
                                MWPLog.message("Restart poller on telemetry timeout\n");
                                have_status = false;
                                xbits = icount = api_cnt = 0;
                                init_sstats();
                                last_tm = 0;
                                lastp.start();
                                serstate = SERSTATE.NORMAL;
                                queue_cmd(msp_get_status,null,0);
                                run_queue();
                            }
                        }
                    } else {
                        lastok = lastrx = nticks;
					}

                    if((nticks % STATINTVL) == 0) {
                        gen_serial_stats();
                        telemstatus.update(telstats, item_visible(DOCKLETS.TELEMETRY));
                    }
                }

                if(duration != 0 && duration != last_dura) {
                    int mins;
                    int secs;
                    if(duration < 0) {
                        mins = secs = 0;
                        duration = 0;
                    } else {
                        mins = (int)duration / 60;
                        secs = (int)duration % 60;
                        if(mins != lmin) {
							navstatus.update_duration(mins);
							lmin = mins;
                        }
                    }
                    elapsedlab.set_text("%02d:%02d".printf(mins,secs));
                    last_dura = duration;
                }

                if((nticks % RADARINTVL) == 0) {
					//                    radar_plot.@foreach ((r) => {
					for(unowned SList<RadarPlot?> lp = radar_plot; lp != null; lp = lp.next) {
						unowned RadarPlot r = lp.data;
						var staled = 120*10 ; //(r.source == 2) ? 120*10 : 50;
                            uint delta = nticks - r.lasttick;
                            if (delta > 600*10) {
                                if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE)
                                    MWPLog.message("TRAF-DEL %s %u\n", r.name, r.state);
                                if((r.source & RadarSource.M_ADSB) != 0) {
                                    radarv.remove(r);
                                    markers.remove_radar(r);
                                    radar_plot.remove_all(r);
                                }
                            }
                            else if(delta > 300*10) {
                                if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE)
                                    MWPLog.message("TRAF-HID %s %u\n", r.name, r.state);
                                if((r.source & RadarSource.M_ADSB) != 0) {
                                    r.state = 2; // hidden
									r.alert = RadarAlert.SET;
									radarv.update(ref r, ((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE));
									markers.set_radar_hidden(r);
                                }
                            } else if(delta > staled && r.state != 0 && r.state != 3) {
                                if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE)
                                    MWPLog.message("TRAF-STALE %s %u\n", r.name, r.state);
                                r.state = 3; // stale
								r.alert = RadarAlert.SET;
								radarv.update(ref r, ((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE));
                                markers.set_radar_stale(r);
                            }
                    }
                }
                return Source.CONTINUE;
            });
    }

    private void init_have_home() {
        have_home = false;
        markers.negate_home();
        ls.calc_mission(0);
        home_pos.lat = 0;
        home_pos.lon = 0;
        wp0.lon = xlon = 0;
        wp0.lat = xlat = 0;
        want_special = 0;
    }

    private void send_poll() {
        if(serstate == SERSTATE.POLLER) {
            var req=requests[tcycle];
            lastm = nticks;
            if (req == MSP.Cmds.ANALOG || req == MSP.Cmds.ANALOG2) {
                if (lastm - last_an > MAVINTVL) {
                    last_an = lastm;
                    mavc = 0;
                } else {
                    tcycle = (tcycle + 1) % requests.length;
                    req = requests[tcycle];
                }
            }
                // only is not armed
            if (req == MSP.Cmds.GPSSTATISTICS && armed == 1) {
                tcycle = (tcycle + 1) % requests.length;
                req = requests[tcycle];
            }
            if(req == MSP.Cmds.WP)
                request_wp(0);
            else
                if (req != MSP.Cmds.NOOP)
                    queue_cmd(req, null, 0);
        }
    }

    private void init_craft_icon() {
        if(craft == null) {
            uint8 ctype = vi.mrtype;
            if((SportDev.active || nopoll) && dmrtype != 0 && vi.mrtype == 0)
                ctype = (uint8)dmrtype;
            MWPLog.message("init icon %d %d %d (%s)\n",  ctype, dmrtype, vi.mrtype, nopoll.to_string());
            craft = new Craft(view, ctype, !no_trail,
                              stack_size, mod_points);
            craft.park();
            craft.adjust_z_order(markers.markers);
        }
    }

    private ulong build_pollreqs() {
        ulong reqsize = 0;
        requests.resize(0);
        sensor_alm = false;
        requests += msp_get_status;
        reqsize += (msp_get_status ==  MSP.Cmds.STATUS_EX) ? MSize.MSP_STATUS_EX :
            (msp_get_status ==  MSP.Cmds.INAV_STATUS) ? MSize.MSP2_INAV_STATUS :
            MSize.MSP_STATUS;

        if (msp_get_status ==  MSP.Cmds.INAV_STATUS) {
            requests += MSP.Cmds.ANALOG2;
            reqsize += MSize.MSP_ANALOG2;
        } else {
            requests += MSP.Cmds.ANALOG;
            reqsize += MSize.MSP_ANALOG;
        }
        sflags = NavStatus.SPK.Volts;
        var missing = 0;

        if(force_mag) {
            usemag = true;
		} else {
            usemag = ((sensor & MSP.Sensors.MAG) == MSP.Sensors.MAG);
            if(!usemag && Craft.is_mr(vi.mrtype))
                missing = MSP.Sensors.MAG;
        }

        if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS) {
            sflags |= NavStatus.SPK.GPS;
            if((navcap & NAVCAPS.NAVSTATUS) == NAVCAPS.NAVSTATUS) {
                requests += MSP.Cmds.NAV_STATUS;
                reqsize += MSize.MSP_NAV_STATUS;
            }
            requests += MSP.Cmds.RAW_GPS;
            requests += MSP.Cmds.COMP_GPS;

            if((navcap & NAVCAPS.NAVCONFIG) == 0) {
                requests += MSP.Cmds.GPSSTATISTICS;
                reqsize += MSize.MSP_GPSSTATISTICS;
            }
            requests += MSP.Cmds.WP;

            reqsize += (MSize.MSP_RAW_GPS + MSize.MSP_COMP_GPS+1);
            init_craft_icon();
        } else
            missing |= MSP.Sensors.GPS;

        if((sensor & MSP.Sensors.ACC) == MSP.Sensors.ACC) {
            requests += MSP.Cmds.ATTITUDE;
            reqsize += MSize.MSP_ATTITUDE;
        }

        if(((sensor & MSP.Sensors.BARO) == MSP.Sensors.BARO) || Craft.is_fw(vi.mrtype)) {
            sflags |= NavStatus.SPK.BARO;
            requests += MSP.Cmds.ALTITUDE;
            reqsize += MSize.MSP_ALTITUDE;
        } else
            missing |= MSP.Sensors.BARO;

        if(missing != 0) {
            if(gpscnt < 5) {
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
        } else {
            set_error_status(null);
            gpscnt = 0;
        }
        return reqsize;
    }

    private void map_warn_set_text(bool init = false) {
        if(clutextg != null) {
            var parts= conf.wp_text.split("/");
            if(init) {
                var grey = Clutter.Color.from_string(parts[1]);
                clutextg.color = grey;
                clutextd.color = grey;
            }
            if(window_h != -1) {
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

    private void map_init_warning(Clutter.LayoutManager lm) {
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

    private void map_show_warning(string text) {
        clutextr.set_text(text);
    }

    private void map_hide_warning() {
        clutextr.set_text("");
    }

    private void map_show_wp(string text) {
        clutextg.set_markup(text);
        map_clean = false;
    }

    private void map_show_dist(string text) {
        clutextd.set_markup(text);
        map_clean = false;
    }

    private void map_hide_wp() {
        if(!map_clean) {
            clutextg.set_text("");
            clutextd.set_text("");
            markers.clear_ring();
            map_clean = true;
        }
    }

    private void  alert_broken_sensors(uint8 val) {
        if(val != xs_state) {
            string sound;
            MWPLog.message("sensor health %04x %d %d\n", sensor, val, xs_state);
            if(val == 1) {
                sound = /*(sensor_alm) ? MWPAlert.GENERAL :*/ MWPAlert.RED;
                sensor_alm = true;
                init_craft_icon();
                map_show_warning("SENSOR FAILURE");
            } else {
                sound = MWPAlert.GENERAL;
                map_hide_warning();
                hwstatus[0] = 1;
            }
            play_alarm_sound(sound);
            navstatus.hw_failure(val);
            xs_state = val;
            if(serstate != SERSTATE.TELEM) {
                MWPLog.message("request sensor info\n");
                queue_cmd(MSP.Cmds.SENSOR_STATUS,null,0);
            }
        }
    }

    private void update_sensor_array() {
        alert_broken_sensors((uint8)(sensor >> 15));
        for(int i = 0; i < 5; i++) {
            uint16 mask = (1 << i);
            bool setx = ((sensor & mask) != 0);
            sensor_sts[i+1].label = "<span foreground = \"%s\">▌</span>".printf((setx) ? "green" : "red");
        }
        sensor_sts[0].label = sensor_sts[1].label;
    }

    private void clear_sensor_array() {
        xs_state = 0;
        for(int i = 0; i < 6; i++)
            sensor_sts[i].label = " ";
    }

    private void reboot_status() {
        set_menu_state("reboot", ((msp != null && msp.available && armed == 0)));
        set_menu_state("terminal", ((msp != null && msp.available && armed == 0)));
    }

    private bool armed_processing(uint64 flag, string reason="") {
        bool changed = false;
        if(armed == 0) {
            armtime = 0;
            duration = -1;
            mss.m_wp = -1;
            if(replayer == Player.NONE)
                init_have_home();
            no_ofix = 0;
            gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};
        } else {
            if(armtime == 0)
                time_t(out armtime);

            if(replayer == Player.NONE) {
                time_t(out duration);
                duration -= armtime;
            }
        }

        if(Logger.is_logging) {
            Logger.armed((armed == 1), duration, flag,sensor, telem);
        }

        if(armed != larmed) {
            changed = true;
            navstatus.set_replay_mode((replayer != Player.NONE));
            radstatus.annul();
            if (armed == 1) {
                magdt = -1;
                odo = {0};

                odo.alt = -9999;
                reboot_status();
                init_craft_icon();
                if(!no_trail) {
                    if(craft != null) {
                        markers.remove_rings(view);
                        craft.init_trail();
                    }
                }
                init_have_home();
                MWPLog.message("Craft is armed, special=%x\n", want_special);
                armed_spinner.show();
                armed_spinner.start();
                check_mission_home();
				if(bbvlist != null && bbvlist.vauto) {
					if (bbvlist.vp != null) {
						bbvlist.vp.start_at(bbvlist.timer);
					}
				}
				sflags |= NavStatus.SPK.Volts;

                if (conf.audioarmed == true) {
                    say_state |= NavStatus.SAY_WHAT.Nav;
                    MWPLog.message("Enable nav speak\n");
                    navstatus.set_audio_status(say_state);
                    audio_cb.active = true;
                }
                if(conf.logarmed == true && !mqtt_available) {
                    logb.active = true;
                }

                if(Logger.is_logging) {
                    Logger.armed(true,duration,flag, sensor,telem);
                    if(rhdop != 10000) {
                        LTM_XFRAME xf = LTM_XFRAME();
                        xf = {0};
                        xf.hdop = rhdop;
                        xf.sensorok = (sensor >> 15);
                        Logger.ltm_xframe(xf);
                    }
                }
                odoview.dismiss();
            } else {
                if(odo.time > 5) {
                    MWPLog.message("Distance = %.1f, max speed = %.1f time = %u\n",
                                   odo.distance, odo.speed, odo.time);
                    odoview.display(odo, true);
                    map_hide_wp();
                }
                MWPLog.message("Disarmed %s\n", reason);
                armed_spinner.stop();
                armed_spinner.hide();
                markers.negate_ipos();
                set_menu_state("followme", false);
                duration = -1;
                armtime = 0;
                want_special = 0;
                init_have_home();
                if (conf.audioarmed == true) {
                    audio_cb.active = false;
                    say_state &= ~NavStatus.SAY_WHAT.Nav;
                    if((debug_flags & DEBUG_FLAGS.ADHOC) != 0)
                        MWPLog.message("Disable nav speak\n");
                    navstatus.set_audio_status(say_state);
                }
                if(conf.logarmed == true) {
                    if(Logger.is_logging)
                        Logger.armed(false,duration,flag, sensor,telem);
                    logb.active=false;
                }
                navstatus.reset_states();
                reboot_status();
            }
        }
        larmed = armed;
        return changed;
    }

    private void check_mission_home() {
        if (have_home) {
            var homed = false;
            var ms = ls.to_mission();
            if(ms.npoints > 0) {
                for(var i = 0; i < ms.npoints; i++) {
                    var mi = ms.get_waypoint(i);
                    if (mi.flag == 0x48) {
                        homed = true;
                        mi.lat = home_pos.lat;
                        mi.lon = home_pos.lon;
                        ms.set_waypoint(mi, i);
                    }
                }
                if(homed) {
//					MWPLog.message("MSX: Instantiate from ## homed\n");
//                    instantiate_mission(ms);
                    FakeHome.usedby |= FakeHome.USERS.Mission;
                    ls.set_fake_home_pos(home_pos.lat, home_pos.lon);
                }
            }
        }
    }

    private void update_odo(double spd, double ddm) {
        odo.time = (uint)duration;
        odo.distance += ddm;
        if (spd > odo.speed) {
            odo.speed = spd;
            odo.spd_secs = odo.time;
        }
        if(NavStatus.cg.range > odo.range) {
            odo.range = NavStatus.cg.range;
            odo.rng_secs = odo.time;
        }
        double estalt = (double)NavStatus.alti.estalt/100.0;
        if (estalt > odo.alt) {
            odo.alt = estalt;
            odo.alt_secs = odo.time;
        }
    }

    private void reset_poller() {
        lastok = nticks;
        if(serstate != SERSTATE.NONE && serstate != SERSTATE.TELEM) {
            if(nopoll == false)
                serstate = SERSTATE.POLLER;
            msg_poller();
        }
    }

    private void gps_alert(uint8 scflags) {
        bool urgent = ((scflags & SAT_FLAGS.URGENT) != 0);
        bool beep = ((scflags & SAT_FLAGS.BEEP) != 0);
        navstatus.sats(_nsats, urgent);
        if(beep && replayer == Player.NONE)
            play_alarm_sound(MWPAlert.SAT);
        nsats = _nsats;
        last_ga = lastrx;
    }

    private void sat_coverage() {
        uint8 scflags = 0;
        if(nsats != _nsats) {
            if(_nsats < msats) {
                if(_nsats < nsats) {
                    scflags = SAT_FLAGS.URGENT|SAT_FLAGS.BEEP;
                } else if((lastrx - last_ga) > USATINTVL) {
                    scflags = SAT_FLAGS.URGENT;
                }
            } else {
                if(nsats < msats)
                    scflags = SAT_FLAGS.URGENT;
                else if((lastrx - last_ga) > UUSATINTVL) {
                    scflags = SAT_FLAGS.NEEDED;
                }
            }
        }

        if((scflags == 0) && ((lastrx - last_ga) > SATINTVL)) {
            scflags = SAT_FLAGS.NEEDED;
        }

        if(scflags != SAT_FLAGS.NONE) {
            gps_alert(scflags);
            mss.m_nsats = (uint8)GPSInfo.nsat;
            mss.m_fix = (uint8)GPSInfo.fix;
            mss.sats_changed(mss.m_nsats, mss.m_fix);
        }
    }

    private void flash_gps() {
        gpslab.label = "<span foreground = \"%s\">⬤</span>".printf(conf.led);
        Timeout.add(50, () => {
                gpslab.set_label("◯");
                return false;
            });
    }

    private string board_by_id() {
        string board = "mysteryFC";
        switch (vi.board) {
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

    private string get_arm_fail(uint32 af, char sep=',') {
        StringBuilder sb = new StringBuilder ();
        if(af == 0)
            sb.append("Ready to Arm");
        else {
            for(var i = 0; i < 32; i++) {
                if((af & (1<<i)) != 0) {
                    if(i < arm_fails.length) {
                        if (arm_fails[i] != null) {
                            sb.append(arm_fails[i]);
                            if ((1 << i) == ARMFLAGS.ARMING_DISABLED_NAVIGATION_UNSAFE) {
                                bool navmodes = true;

                                sb.append_c(sep);
                                if(gpsstats.eph > inav_max_eph_epv ||
                                    gpsstats.epv > inav_max_eph_epv) {
                                    sb.append(" • Fix quality");
                                    sb.append_c(sep);
                                    navmodes = false;
                                }
                                if(_nsats < msats ) {
                                    sb.append_printf(" • %d satellites", _nsats);
                                    sb.append_c(sep);
                                    navmodes = false;
                                }

								if(wpdist > 0) {
									var ms = ls.to_mission();
									if(ms.npoints > 0) {
										double cw, dw;
										var mi = ms.get_waypoint(0);
										Geo.csedist(xlat, xlon, mi.lat, mi.lon,
													out dw, out cw);
										dw /= 1852;
										if(dw > wpdist) {
											sb.append_printf(" • 1st wp distance %dm/%.1fm", wpdist, dw);
											sb.append_c(sep);
											navmodes = false;
										};
									}
								}

                                if(navmodes) {
                                    sb.append(" • Reason unknown; is a nav mode engaged?");
                                    sb.append_c(sep);
                                }
                            } else
                                sb.append_c(sep);
                        }
                    } else {
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

    private void handle_msp_status(uint8[]raw, uint len) {
        uint64 bxflag;
        uint64 lmask;

        SEDE.deserialise_u16(raw+4, out sensor);
        if(msp_get_status != MSP.Cmds.INAV_STATUS) {
            uint32 bx32;
            SEDE.deserialise_u32(raw+6, out bx32);
            bxflag = bx32;
        } else
            SEDE.deserialise_u64(raw+13, out bxflag);

        lmask = (angle_mask|horz_mask);

        armed = ((bxflag & arm_mask) == arm_mask) ? 1 : 0;

        if (nopoll == true) {
            have_status = true;
            if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS) {
                sflags |= NavStatus.SPK.GPS;
                init_craft_icon();
            }
            update_sensor_array();
        } else {
            uint32 arm_flags = 0;
            uint16 loadpct;
            if(msp_get_status != MSP.Cmds.STATUS) {
                if(msp_get_status == MSP.Cmds.STATUS_EX) {
                    uint16 xaf;
                    SEDE.deserialise_u16(raw+13, out xaf);
                    arm_flags = xaf;
                    SEDE.deserialise_u16(raw+11, out loadpct);
                    profile = raw[10];
                } else {// msp2_inav_status
                    SEDE.deserialise_u32(raw+9, out arm_flags);
                    SEDE.deserialise_u16(raw+6, out loadpct);
                    profile = (raw[8] & 0xf);
                }

                if(arm_flags != xarm_flags) {
                    xarm_flags = arm_flags;

                    string arming_msg = get_arm_fail(xarm_flags);
                    MWPLog.message("Arming flags: %s (%04x), load %d%% %s\n",
                                   arming_msg, xarm_flags, loadpct,
                                   msp_get_status.to_string());


                    if (conf.audioarmed == true)
                        audio_cb.active = true;

                    if(audio_cb.active == true)
                        navstatus.arm_status(arming_msg);

                    if((arm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0) {
                        arm_warn.show();
                    } else {
                        arm_warn.hide();
                    }
                }
            } else
                profile = raw[10];

            if(have_status == false) {
                have_status = true;
                StringBuilder sb0 = new StringBuilder ();
                foreach (MSP.Sensors sn in MSP.Sensors.all()) {
                    if((sensor & sn) == sn) {
                        sb0.append(sn.to_string());
                        sb0.append_c(' ');
                    }
                }
                update_sensor_array();
                MWPLog.message("Sensors: %s (%04x)\n", sb0.str, sensor);

                if(!prlabel) {
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
                MWPLog.message("%s %s\n", verlab.label, typlab.label);

                if(replayer == Player.NONE) {
                    MWPLog.message("switch val == %08x (%08x)\n", bxflag, lmask);
                    if(Craft.is_mr(vi.mrtype) && ((bxflag & lmask) == 0) && robj == null) {
                        if(conf.checkswitches)
                            swd.runner();
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

                if(nopoll == false && nreqs > 0) {
                    if  (replayer == Player.NONE) {
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
            } else {
                if(gpscnt != 0 && ((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS)) {
                    build_pollreqs();
                }
                if(sensor != xsensor) {
                    update_sensor_array();
                    xsensor = sensor;
                }
            }

                // acro/horizon/angle changed
            uint8 ltmflags = 0;
            var mchg = bxflag != xbits;

            if((bxflag & lmask) != (xbits & lmask)) {
                report_bits(bxflag);
            }

            if ((bxflag & horz_mask) != 0)
                ltmflags = MSP.LTM.horizon;
            else if((bxflag & angle_mask) != 0)
                ltmflags = MSP.LTM.angle;
            else
                ltmflags = MSP.LTM.acro;

            if (armed != 0) {

                if (fs_mask != 0) {
                    bool failsafe = ((bxflag & fs_mask) != 0);
                    if(xfailsafe != failsafe) {
                        if(failsafe) {
                            arm_flags |=  ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
                            MWPLog.message("Failsafe asserted %ds\n", duration);
                            map_show_warning("FAILSAFE");
                        } else {
                            MWPLog.message("Failsafe cleared %ds\n", duration);
                            map_hide_warning();
                        }
                        xfailsafe = failsafe;
                    }
                }
                if ((rth_mask != 0) &&
                    ((bxflag & rth_mask) != 0) &&
                    ((xbits & rth_mask) == 0)) {
                    MWPLog.message("set RTH on %08x %u %ds\n", bxflag,bxflag,
                                   (int)duration);
                    want_special |= POSMODE.RTH;
                    ltmflags = MSP.LTM.rth;
                } else if ((ph_mask != 0) &&
                         ((bxflag & ph_mask) != 0) &&
                         ((xbits & ph_mask) == 0)) {
                    MWPLog.message("set PH on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.PH;
                    ltmflags = MSP.LTM.poshold;
                } else if ((wp_mask != 0) &&
                         ((bxflag & wp_mask) != 0) &&
                         ((xbits & wp_mask) == 0)) {
                    MWPLog.message("set WP on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.WP;
                    ltmflags = MSP.LTM.waypoints;
                } else if ((cr_mask != 0)  &&
                           ((bxflag & cr_mask) != 0) &&
                           ((xbits & cr_mask) == 0)) {
                    MWPLog.message("set CRUISE on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.CRUISE;
                    ltmflags = MSP.LTM.cruise;
                } else if ((xbits != bxflag) && craft != null) {
                    craft.set_normal();
                }


                if (want_special != 0) {
                    var lmstr = MSP.ltm_mode(ltmflags);
                    fmodelab.set_label(lmstr);
                }
            }
            xbits = bxflag;
            var achg = armed_processing(bxflag,"msp");
            if(achg || mchg)
                update_mss_state(ltmflags);
        }
    }

    private void centre_mission(Mission ms, bool ctr_on) {
        MissionItem [] mis = ms.get_ways();
        if(mis.length > 0) {
            ms.maxx = ms.maxy = -999.0;
            ms.minx = ms.miny = 999.0;
            foreach(MissionItem mi in mis) {
                if(mi.action != MSP.Action.RTH &&
                   mi.action != MSP.Action.JUMP &&
                   mi.action != MSP.Action.SET_HEAD) {
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
            if (ctr_on) {
                map_centre_on(ms.cy, ms.cx);
                ms.zoom = guess_appropriate_zoom(bb_from_mission(ms));
                set_view_zoom(ms.zoom);
            }
            map_moved();
			valid_flash();
		}
    }

    private void map_centre_on(double y, double x) {
        view.center_on(ly=y, lx=x);
        anim_cb();
    }

    private void try_centre_on(double xlat, double xlon) {
        if(!view.get_bounding_box().covers(xlat, xlon)) {
            var mlat = view.get_center_latitude();
            var mlon = view.get_center_longitude();
            double alat, alon;
            double msize = Math.fmin(mapsize.width, mapsize.height);
            double dist,_cse;
            Geo.csedist(xlat, xlon, mlat, mlon, out dist, out _cse);

            if(dist * 1852.0 > msize) {
                alat = xlat;
                alon = xlon;
            } else {
                alat = (mlat + xlat)/2.0;
                alon = (mlon + xlon)/2.0;
            }
            map_centre_on(alat,alon);
        }
    }

    private bool update_pos_info() {
        bool pv;
        pv = pos_valid(GPSInfo.lat, GPSInfo.lon);

        if(pv == true) {
            if(follow == true) {
                if (centreon == true) {
                    if(conf.use_legacy_centre_on)
                        map_centre_on(GPSInfo.lat,GPSInfo.lon);
                    else
                        try_centre_on(GPSInfo.lat,GPSInfo.lon);
                }
                double cse = (usemag || ((replayer & Player.MWP) == Player.MWP)) ? mhead : GPSInfo.cse;
                craft.set_lat_lon(GPSInfo.lat, GPSInfo.lon,cse);
            }

            int32 talt = (int32)NavStatus.alti.estalt/100;
            int16 tazimuth = (int16)(Math.atan2(talt,  NavStatus.cg.range)/(Math.PI/180.0));
                // Historic MW baggage ...alas
            var brg = NavStatus.cg.direction;
            if(brg < 0)
               brg += 360;
            brg = ((brg + 180) % 360);
            if(mss.dbus_pos_interval == 0 || nticks - lastdbus >= mss.dbus_pos_interval) {
                if(mss.v_lat != GPSInfo.lat ||
                   mss.v_long != GPSInfo.lon ||
                   mss.v_alt != talt)
                    mss.location_changed(GPSInfo.lat, GPSInfo.lon, talt);

                if(mss.v_azimuth != tazimuth ||
                   NavStatus.cg.range != mss.v_range ||
                   (uint32)brg != mss.v_direction)
                    mss.polar_changed(NavStatus.cg.range, brg, tazimuth);
                if(mss.v_spd != (uint32) GPSInfo.spd || mss.v_cse != (uint32)GPSInfo.cse)
                    mss.velocity_changed((uint32)GPSInfo.spd, (uint32)GPSInfo.cse);
                lastdbus = nticks;
            }
            mss.v_lat = GPSInfo.lat;
            mss.v_long = GPSInfo.lon;
            mss.v_alt = talt;
            mss.v_spd = (uint32)GPSInfo.spd;
            mss.v_cse = (uint32)GPSInfo.cse;
            mss.v_azimuth = tazimuth;
            mss.v_range = NavStatus.cg.range;
            mss.v_direction = brg;
        }
        return pv;
    }

    private void show_wp_distance(uint8 np) {
        if (wp_resp.length == NavStatus.nm_pts) {
            uint fs=(uint)conf.wp_dist_fontsize*1024;
            np = np - 1;
            if( wp_resp[np].action != MSP.Action.JUMP &&
                wp_resp[np].action != MSP.Action.SET_HEAD &&
                wp_resp[np].action != MSP.Action.SET_POI) {
                double lat,lon;

                if(wp_resp[np].action == MSP.Action.RTH) {
                    lat = home_pos.lat;
                    lon = home_pos.lon;
                } else {
                    lat = wp_resp[np].lat;
                    lon = wp_resp[np].lon;
                }
                double dist,cse;
                Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                            lat, lon, out dist, out cse);
                StringBuilder sb = new StringBuilder();
                if( wp_resp[np].action ==  MSP.Action.POSHOLD_TIME &&
                    NavStatus.n.nav_mode == 4) {
                    if(phtim == 0)
                        phtim = duration;
                    var cdown = wp_resp[np].param1 - (duration - phtim);
                    sb.append_printf("<span size=\"%u\">PH for %lus", fs, cdown);
                    sb.append("</span>");
                } else {
                    phtim = 0;
                    dist *= 1852.0;
                    var icse = Math.lrint(cse) % 360;
                    sb.append_printf("<span size=\"%u\">%.1fm %ld°", fs, dist, icse);
                    if(GPSInfo.spd > 0.0 && dist > 1.0)
                        sb.append_printf(" %ds", (int)(dist/GPSInfo.spd));
                    else
                        sb.append(" --s");
                    sb.append("</span>");
                }
                map_show_dist(sb.str);
            }
        }
    }

    private void report_special_wp(MSP_WP w) {
        double lat, lon;
        lat = w.lat/10000000.0;
        lon = w.lon/10000000.0;
        if (w.wp_no == 0) {
            wp0.lat = lat;
            wp0.lon = lon;
        } else {
            MWPLog.message("Special WP#%d (%d) %.6f %.6f %dm %d°\n", w.wp_no, w.action, lat, lon, w.altitude/100, w.p1);
        }
    }

    private void handle_mm_download(uint8[] raw, uint len) {
        have_wp = true;
        MSP_WP w = MSP_WP();
        uint8* rp = raw;
        if((wpmgr.wp_flag & WPDL.CANCEL) != 0) {
			remove_tid(ref upltid);
			MWPCursor.set_normal_cursor(window);
			wp_reset_poller();
			validatelab.set_text("⚠"); // u+26a0
			mwp_warning_box("Upload cancelled", Gtk.MessageType.ERROR,10);
            return;
		}
        w.wp_no = *rp++;
        w.action = *rp++;
        rp = SEDE.deserialise_i32(rp, out w.lat);
        rp = SEDE.deserialise_i32(rp, out w.lon);
		rp = SEDE.deserialise_i32(rp, out w.altitude);
		rp = SEDE.deserialise_i16(rp, out w.p1);

        if(w.wp_no == 0 || w.wp_no > 253) {
            report_special_wp(w);
            return;
        }
		rp = SEDE.deserialise_i16(rp, out w.p2);
		rp = SEDE.deserialise_i16(rp, out w.p3);
		w.flag = *rp;
        wpmgr.wps += w;
		bool done;

		if(vi.fc_vers >= FCVERS.hasWP_V4)
			done = (wpmgr.wps.length == wpmgr.npts);
		else
			done = (w.flag == 0xa5);

		if(done) {
			clear_mission();
			var mmsx = MultiM.wps_to_missonx(wpmgr.wps);
			var nwp = check_mission_length(mmsx);
			if(nwp > 0) {
				msx = mmsx;
				setup_mission_from_mm();
				MWPLog.message("Download completed #%d\n", nwp);
				validatelab.set_text("✔"); // u+2714
			} else {
				mwp_warning_box("Fallback safe mission, 0 points", Gtk.MessageType.INFO,10);
				MWPLog.message("Fallback safe mission\n");
			}
			MWPCursor.set_normal_cursor(window);
            remove_tid(ref upltid);
            wp_reset_poller();
		} else {
            validatelab.set_text("WP:%3d".printf(w.wp_no));
			request_wp(w.wp_no+1);
		}
	}

    private void process_msp_analog(MSP_ANALOG an) {
        if ((replayer & Player.MWP) == Player.NONE) {
            if(have_mspradio)
                an.rssi = 0;
            else
                radstatus.update_rssi(an.rssi, item_visible(DOCKLETS.RADIO));
            curr.centiA = an.amps;
            curr.mah = an.powermetersum;
            if(curr.centiA != 0 || curr.mah != 0) {
                curr.ampsok = true;
                navstatus.current(curr, 2);
                if (curr.centiA > odo.amps)
                    odo.amps = curr.centiA;
            }
            if(Logger.is_logging) {
                Logger.analog(an);
            }
            set_bat_stat(an.vbat);
        }
    }

    public void handle_radar(MWSerial s, MSP.Cmds cmd, uint8[] raw, uint len,
                              uint8 xflags, bool errs) {
		double rlat, rlon;
        nopoll = true;
		if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE) {
			MWPLog.message("RDR-msg: %s\n", cmd.to_string());
		}

		switch(cmd) {
            case MSP.Cmds.NAME:
                var node = "MWP Fake Node";
                s.send_command(cmd, node, node.length, true);
                break;
            case MSP.Cmds.RAW_GPS:
                   uint8 oraw[18]={0};
                   uint8 *p = &oraw[0];

                    *p++ = 2;
                    *p++ = 42;

					if (GCSIcon.get_location(out rlat, out rlon) == false) {
						if(have_home) {
							rlat = home_pos.lat;
							rlon = home_pos.lon;
						} else {
							rlat = view.get_center_latitude();
							rlon = view.get_center_longitude();
						}
					}
                    p = SEDE.serialise_i32(p, (int)(rlat*1e7));
                    p = SEDE.serialise_i32(p, (int)(rlon*1e7));
                    p = SEDE.serialise_i16(p, 0);
                    p = SEDE.serialise_u16(p, 0);
                    p = SEDE.serialise_u16(p, 0);
                    SEDE.serialise_u16(p, 99);
                    if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE) {
                        MWPLog.message("RDR-rgps: Lat, Lon %f %f\n", rlat, rlon);
                        StringBuilder sb = new StringBuilder("RDR-rgps:");
                        foreach(var r in oraw)
                            sb.append_printf(" %02x", r);
                        sb.append_c('\n');
                        MWPLog.message(sb.str);
                    }
                    s.send_command(cmd, oraw, 18, true);
                break;
            case MSP.Cmds.FC_VARIANT:
				uint8 []oraw;
				if (GCSIcon.get_location(out rlat, out rlon)) {
					oraw = "INAV".data;
				} else {
					oraw = "GCS".data; //{0x47, 0x43, 0x53}; // 'GCS'
				}
				s.send_command(cmd, oraw, oraw.length, true);
                break;
            case MSP.Cmds.FC_VERSION:
				uint8 oraw[3] = {6,6,6};
				s.send_command(cmd, oraw, oraw.length,true);
				break;
            case MSP.Cmds.ANALOG:
				uint8 []oraw = {0x76, 0x4, 0x0, 0x0, 0x0, 0x0, 0x0};
				s.send_command(cmd, oraw, oraw.length,true);
                break;
            case MSP.Cmds.STATUS:
				uint8 []oraw = {0xe8, 0x3, 0x0, 0x0, 0x83, 0x0, 0x0, 0x10, 0x10, 0x0, 0x0};
				s.send_command(cmd, oraw, oraw.length,true);
                break;
            case MSP.Cmds.BOXIDS:
				uint8 []oraw = {0x0, 0x33, 0x1, 0x2, 0x23, 0x5, 0x6, 0x7, 0x20, 0x8, 0x3, 0x21, 0xc, 0x24, 0x25, 0x15, 0xd, 0x13, 0x1a, 0x26, 0x1b, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c};
                    s.send_command(cmd, oraw, oraw.length,true);
                break;

            case MSP.Cmds.COMMON_SET_RADAR_POS:
                process_inav_radar_pos(raw,len);
                break;
            case MSP.Cmds.MAVLINK_MSG_ID_TRAFFIC_REPORT:
                process_mavlink_radar(raw);
                break;
            case MSP.Cmds.MAVLINK_MSG_ID_OWNSHIP:
//                dump_mav_os_msg(raw);
                break;
            default:
				if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE) {
					MWPLog.message("RADAR: %s %d (%u)\n", cmd.to_string(), cmd, len);
				}
                break;
        }
    }

    private void msp_publish_home(uint8 id) {
        if(id < SAFEHOMES.maxhomes) {
            var h = safehomed.get_home(id);
            uint8 tbuf[10];
            tbuf[0] = id;
            tbuf[1] = (h.enabled) ? 1 : 0;
            var ll = (int32) (h.lat * 10000000);
            SEDE.serialise_i32(&tbuf[2], ll);
            ll = (int32)(h.lon * 10000000);
            SEDE.serialise_i32(&tbuf[6], ll);
            queue_cmd(MSP.Cmds.SET_SAFEHOME, tbuf, 10);
        } else {
            queue_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
        }
        run_queue();
    }

    private int16 calc_vario(int ealt) {
        int16 diff = 0;
        if((replayer & (Player.BBOX_FAST)) != Player.FAST_MASK) {
            var i = Varios.idx % NVARIO;
            Varios.alts[i] = ealt;
            Varios.ticks[i] = nticks;
            Varios.idx += 1;
            if (Varios.idx > NVARIO-1) {
                var j = (i + 1) % NVARIO;
                int adiff = ealt - Varios.alts[j];
                var et  = nticks - Varios.ticks[j];
                double fdiff = (int)(((double)adiff*10)/et);
                diff = (int16)fdiff;
            }
        }
        return diff;
    }

	private void wp_reset_poller() {
		wpmgr.npts = 0;
		wpmgr.wp_flag = 0;
		wpmgr.wps = {};
		reset_poller();
	}

    public void handle_serial(MSP.Cmds cmd, uint8[] raw, uint len, uint8 xflags, bool errs) {
        if(cmd >= MSP.Cmds.LTM_BASE) {
            telem = true;
            if (seenMSP == false)
                nopoll = true;

            if (replayer != Player.MWP && cmd != MSP.Cmds.MAVLINK_MSG_ID_RADIO) {
                if (errs == false) {
                    if(last_tm == 0) {
                        var mtype= (cmd >= MSP.Cmds.MAV_BASE) ? "MAVlink" : "LTM";
                        var mstr = "%s telemetry".printf(mtype);
                        MWPLog.message("%s\n", mstr);
                        if (conf.manage_power && inhibit_cookie == 0) {
                            inhibit_cookie = inhibit(null, ApplicationInhibitFlags.IDLE|ApplicationInhibitFlags.SUSPEND,"mwp telem");
                            dtnotify.send_notification("mwp", "Inhibiting screen/idle/suspend");
                            MWPLog.message("Managing screen idle and suspend\n");
                        }
                        serstate = SERSTATE.TELEM;
                        init_sstats();
                        if(naze32 != true) {
                            naze32 = true;
                            mwvar = vi.fctype = MWChooser.MWVAR.CF;
                            verlab.label = verlab.tooltip_text = mstr;
                        }
                    }
                    last_tm = nticks;
                    last_gps = nticks;
                    if(last_tm == 0)
                        last_tm =1;
                }
            }
        } else {
            seenMSP = true;
        }

        if (cmd >= MSP.Cmds.MAV_BASE && cmd < MSP.Cmds.MAV_BASE+256) {
            if(mavc == 0 &&  msp.available) {
                send_mav_heartbeat();
            }
            mavc = (mavc+1) & MAV_BEAT_MASK;
        }

        if(errs == true) {
            lastrx = lastok = nticks;
            MWPLog.message("MSP Error: %s[%d] %s\n", cmd.to_string(), cmd,
                           (cmd == MSP.Cmds.COMMON_SETTING) ? (string)lastmsg.data : "");
            switch(cmd) {
			case MSP.Cmds.NAME:
				if (xflags == '<') {
                        handle_radar(msp, cmd, raw, len, xflags, errs);
				} else {
					queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
					run_queue();
				}
				break;
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
			case  MSP.Cmds.COMMON_SET_SETTING:
				run_queue();
				break;
			default:
				queue_cmd(msp_get_status,null,0);
				run_queue();
				break;
            }
            return;
        }
        else if(((debug_flags & DEBUG_FLAGS.MSP) != DEBUG_FLAGS.NONE) && cmd < MSP.Cmds.LTM_BASE) {
            MWPLog.message("Process MSP %s\n", cmd.to_string());
        }

        if(fwddev != null && fwddev.available) {
            if(cmd < MSP.Cmds.LTM_BASE && conf.forward == FWDS.ALL) {
                fwddev.send_command(cmd, raw, len);
            }
            if(cmd >= MSP.Cmds.LTM_BASE && cmd < MSP.Cmds.MAV_BASE) {
                if (conf.forward == FWDS.LTM || conf.forward == FWDS.ALL ||
                    (conf.forward == FWDS.minLTM &&
                     (cmd == MSP.Cmds.TG_FRAME ||
                      cmd == MSP.Cmds.TA_FRAME ||
                      cmd == MSP.Cmds.TS_FRAME )))
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
                  cmd == MSP.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW)))) {
                fwddev.send_mav((cmd - MSP.Cmds.MAV_BASE), raw, len);
            }
        }

        if(Logger.is_logging)
            Logger.log_time();

        if(cmd != MSP.Cmds.RADIO) {
            lastrx = lastok = nticks;
            if(rxerr) {
                set_error_status(null);
                rxerr=false;
            }
        }
        switch(cmd) {
            case MSP.Cmds.API_VERSION:
                have_api = true;
                if(len > 32) {
                    naze32 = true;
                    mwvar = vi.fctype = MWChooser.MWVAR.CF;
                    var vers="CF mwc %03d".printf(vi.mvers);
                    verlab.label = verlab.tooltip_text = vers;
                    queue_cmd(MSP.Cmds.BOXNAMES,null,0);
                } else {
                    vi.fc_api = raw[1] << 8 | raw[2];
                    xarm_flags = 0xffff;
                    if (vi.fc_api >= APIVERS.mspV2) {
                        msp.use_v2 = true;
                        queue_cmd(MSP.Cmds.NAME,null,0);
                    } else {
                        queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
					}
                    MWPLog.message("Using MSP v%c %04x\n", (msp.use_v2) ? '2' : '1', vi.fc_api);
                }
                break;

            case MSP.Cmds.NAME:
                if (xflags == '<') {
                    handle_radar(msp, cmd, raw, len, xflags, errs);
                    return;
                } else {
                    raw[len] = 0;
                    vname = (string)raw;
                    MWPLog.message("Model name: \"%s\"\n", vname);
                    int mx = mmap.get_model_type(vname);
                    if (mx != 0) {
                        vi.mrtype = (uint8)mx;
                        queue_cmd(MSP.Cmds.BOARD_INFO,null,0);
                    } else if (vi.fc_api >= APIVERS.mixer)
						queue_cmd(MSP.Cmds.INAV_MIXER,null,0);
					else
						queue_cmd(MSP.Cmds.BOARD_INFO,null,0);

                    set_typlab();
                }
                break;

            case MSP.Cmds.BOXIDS:
                if (xflags == '<') {
                    handle_radar(msp, cmd, raw, len, xflags, errs);
                    return;
                }
                break;

            case MSP.Cmds.INAV_MIXER:
                uint16 hx;
                hx = raw[6]<<8|raw[5];
                MWPLog.message("V2 mixer %u %u\n", raw[5], raw[3]);
                if(hx != 0 && hx < 0xff)
                    vi.mrtype = raw[5]; // legacy types only
                else {
                    switch(raw[3]) {
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
                rp = SEDE.deserialise_i32(rp, out rtcsecs);
                SEDE.deserialise_u16(rp, out millis);
                var now = new DateTime.now_local();
                uint16 locmillis = (uint16)(now.get_microsecond()/1000);
                var rem = new DateTime.from_unix_local((int64)rtcsecs);
                string loc = "RTC local %s.%03u, fc %s.%03u\n".printf(
                    now.format("%FT%T"),
                    locmillis,
                    rem.format("%FT%T"), millis);

                if(rtcsecs == 0) {
                    uint8 tbuf[6];
                    rtcsecs = (uint32)now.to_unix();
                    SEDE.serialise_u32(tbuf, rtcsecs);
                    SEDE.serialise_u16(&tbuf[4], locmillis);
                    queue_cmd(MSP.Cmds.SET_RTC,tbuf, 6);
                    run_queue();
                }

                MWPLog.message(loc);

                if(need_mission) {
                    need_mission = false;
                    if(conf.auto_restore_mission) {
                        MWPLog.message("Auto-download FC mission\n");
                        download_mission();
                    }
                }
                break;

            case MSP.Cmds.BOARD_INFO:
                raw[4]=0;
                vi.board = (string)raw[0:3];
                if(len > 8) {
                    raw[len] = 0;
                    vi.name = (string)raw[9:len];
                } else
                    vi.name = null;
                queue_cmd(MSP.Cmds.FC_VARIANT,null,0);
                break;

            case MSP.Cmds.FC_VARIANT:
                if (xflags == '<') {
                    handle_radar(msp, cmd, raw, len, xflags, errs);
                    return;
                } else {
                    naze32 = true;
                    raw[len] = 0;
                    inav = false;
                    vi.fc_var = (string)raw[0:len];
                    if (have_fcv == false) {
                        have_fcv = true;
                        switch(vi.fc_var) {
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
                }
                break;

            case MSP.Cmds.FEATURE:
                uint32 fmask;
                SEDE.deserialise_u32(raw, out fmask);
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
                SEDE.deserialise_u32(raw+5, out fsize);
                SEDE.deserialise_u32(raw+9, out used);
                if(fsize > 0) {
                    var pct = 100 * used  / fsize;
                    MWPLog.message ("Data Flash %u /  %u (%u%%)\n", used, fsize, pct);
                    if(conf.flash_warn > 0 && pct > conf.flash_warn)
                        mwp_warning_box("Data flash is %u%% full".printf(pct),
                                        Gtk.MessageType.WARNING);
                } else
                    MWPLog.message("Flash claims to be 0 bytes!!\n");

                queue_cmd(MSP.Cmds.FC_VERSION,null,0);
                break;

            case MSP.Cmds.FC_VERSION:
                if (xflags == '<') {
                    handle_radar(msp, cmd, raw, len, xflags, errs);
                    return;
                } else {
                    if(have_fcvv == false) {
                        have_fcvv = true;
                        set_menu_state("reboot", true);
                        set_menu_state("terminal", true);
                        vi.fc_vers = raw[0] << 16 | raw[1] << 8 | raw[2];
                        safehomed.online_change(vi.fc_vers);

                        var fcv = "%s v%d.%d.%d".printf(vi.fc_var,raw[0],raw[1],raw[2]);
                        verlab.label = verlab.tooltip_text = fcv;
                        if(inav) {
                            if(vi.fc_vers < FCVERS.hasMoreWP)
                                wp_max = 15;
                            else if (vi.board != "AFNA" && vi.board != "CC3D")
                                wp_max =  (vi.fc_vers >= FCVERS.hasWP_V4) ? (uint8)conf.max_wps :  60;
                            else
                                wp_max = 30;

                            mission_eeprom = (vi.board != "AFNA" &&
                                              vi.board != "CC3D" &&
                                              vi.fc_vers >= FCVERS.hasEEPROM);

                            msp_get_status = (vi.fc_api < 0x200) ? MSP.Cmds.STATUS :
                                (vi.fc_vers >= FCVERS.hasV2STATUS) ? MSP.Cmds.INAV_STATUS : MSP.Cmds.STATUS_EX;
                            // ugly hack for jh flip32 franken builds post 1.73
                            if((vi.board == "AFNA" || vi.board == "CC3D") &&
                               msp_get_status == MSP.Cmds.INAV_STATUS)
                                msp_get_status = MSP.Cmds.STATUS_EX;

                            if (vi.fc_api >= APIVERS.mspV2 && vi.fc_vers >= FCVERS.hasTZ && conf.adjust_tz) {
                                var dt = new DateTime.now_local();
                                int16 tzoffm = (short)((int64)dt.get_utc_offset()/(1000*1000*60));
                                if(tzoffm != 0) {
                                    MWPLog.message("set TZ offset %d\n", tzoffm);
                                    queue_cmd(MSP.Cmds.COMMON_SET_TZ, &tzoffm, sizeof(int16));
                                }  else
                                    queue_cmd(MSP.Cmds.BUILD_INFO, null, 0);
                            } else
                                queue_cmd(MSP.Cmds.BUILD_INFO, null, 0); //?BOXNAMES?

                            sticks.set_rc_style((vi.fc_vers < FCVERS.hasRCDATA));
                        } else {
                            queue_cmd(MSP.Cmds.BOXNAMES,null,0);
                        }
                    }
                }
                break;

            case MSP.Cmds.BUILD_INFO:
                if(len > 18) {
                    uint8 gi[16] = raw[19:len];
                    gi[len-19] = 0;
                    vi.fc_git = (string)gi;
                }
                uchar vs[4];
                SEDE.serialise_u32(vs, vi.fc_vers);
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
                if (icount == 0) {
                    vi = {0};
                    vi.mvers = raw[0];
                    vi.mrtype = raw[1];
//                    if(dmrtype != 0)
//                        vi.mrtype = (uint8)dmrtype;
                    craft = null;
                    prlabel = false;
                    SEDE.deserialise_u32(raw+3, out capability);
                    MWPLog.message("set mrtype=%u cap =%x\n", vi.mrtype, raw[3]);
                    MWChooser.MWVAR _mwvar = mwvar;

                    if(mwvar == MWChooser.MWVAR.AUTO) {
                        naze32 = ((capability & MSPCaps.CAP_PLATFORM_32BIT) != 0);
                    } else {
                        naze32 = mwvar == MWChooser.MWVAR.CF;
                    }

                    if(naze32 == true) {
                        if(force_nc == false)
                            navcap = NAVCAPS.NONE;
                    } else {
                        if ((raw[3] & 0x10) == 0x10) {
                            navcap = NAVCAPS.WAYPOINTS|NAVCAPS.NAVSTATUS|NAVCAPS.NAVCONFIG;
                        } else {
                            navcap = NAVCAPS.NONE;
                        }
                        set_menu_state("reboot", false);
                        set_menu_state("terminal", false);
                    }
                    if(mwvar == MWChooser.MWVAR.AUTO) {
                        if(naze32) {
                            _mwvar = MWChooser.MWVAR.CF;
                        } else {
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
                if(replayer == Player.NONE) {
                    var ncbits = (navcap & (NAVCAPS.NAVCONFIG|NAVCAPS.INAV_MR|NAVCAPS.INAV_FW));
                    if(navcap != NAVCAPS.NONE) {
						set_menu_state("upload-mission", true);
						if(vi.fc_vers >= FCVERS.hasWP_V4)
							set_menu_state("upload-missions", true);
						set_menu_state("download-mission", true);
                    }

                    if (ncbits != 0) {
                        set_menu_state("navconfig", true);
                        if(mission_eeprom) {
                            set_menu_state("restore-mission", true);
                            set_menu_state("store-mission", true);
                            if(inav)
                                set_menu_state("mission-info", true);
                        }

                        MWPLog.message("Generate navconf %x %s\n", navcap, mission_eeprom.to_string());
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
                string []bsx = boxnames.split(";");
                int i = 0;
                foreach(var bs in bsx) {
                    switch(bs) {
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
                    case "NAV CRUISE":
                        cr_mask = (1 << i);
                        break;
                    case "FAILSAFE":
                        fs_mask = (1 << i);
                        break;
                    }
                    i++;
                }
                MWPLog.message("Masks arm=%jx angle=%jx horz=%jx ph=%jx rth=%jx wp=%jx cr=%jx fs=%jx\n",
                               arm_mask, angle_mask, horz_mask, ph_mask,
                               rth_mask, wp_mask, cr_mask, fs_mask);

                if(craft != null)
                    craft.set_icon(vi.mrtype);

                set_typlab();

                if(Logger.is_logging) {
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
                SEDE.deserialise_u16(raw, out gpsstats.last_message_dt);
                SEDE.deserialise_u16(raw+2, out gpsstats.errors);
                SEDE.deserialise_u16(raw+6, out gpsstats.timeouts);
                SEDE.deserialise_u16(raw+10, out gpsstats.packet_count);
                SEDE.deserialise_u16(raw+14, out gpsstats.hdop);
                SEDE.deserialise_u16(raw+16, out gpsstats.eph);
                SEDE.deserialise_u16(raw+18, out gpsstats.epv);
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
                else {
                    if(inav) {
                        wpmgr.wp_flag = WPDL.GETINFO;
                        queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
                    }
                    queue_cmd(MSP.Cmds.ACTIVEBOXES,null,0);
                }
                break;

            case MSP.Cmds.ACTIVEBOXES:
                uint32 ab;
                SEDE.deserialise_u32(raw, out ab);
                StringBuilder sb = new StringBuilder();
                sb.append_printf("Activeboxes %u %08x", len, ab);
                if(len > 4) {
                    SEDE.deserialise_u32(raw+4, out ab);
                    sb.append_printf(" %08x", ab);
                }
                sb.append_c('\n');
                MWPLog.message(sb.str);
                if(vi.fc_vers >= FCVERS.hasTZ) {
                    string maxdstr = (vi.fc_vers >= FCVERS.hasWP1m) ? "nav_wp_max_safe_distance" : "nav_wp_safe_distance";
                    MWPLog.message("Requesting common settings\n");
                    request_common_setting(maxdstr);
                    request_common_setting("inav_max_eph_epv");
					request_common_setting("gps_min_sats");
                    if(vi.fc_vers > FCVERS.hasJUMP && vi.fc_vers <= FCVERS.hasPOI) { // also 2.6 feature
						request_common_setting("nav_rth_home_offset_distance");
                    }
                }
                queue_cmd(msp_get_status,null,0);
                break;

		    case MSP.Cmds.COMMON_SET_SETTING:
				MWPLog.message("Received set_setting\n");
				if ((wpmgr.wp_flag & WPDL.SAVE_ACTIVE) != 0) {
					wpmgr.wp_flag &= ~WPDL.SAVE_ACTIVE;
					queue_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
				} else if ((wpmgr.wp_flag & WPDL.RESET_POLLER) != 0) {
					wp_reset_poller();
				}
				break;

            case MSP.Cmds.COMMON_SETTING:
                switch ((string)lastmsg.data) {
				    case "nav_wp_multi_mission_index":
                        MWPLog.message("Received mm index %u\n", raw[0]);
						if (raw[0] > 0) {
							imdx = raw[0]-1;
						} else {
							imdx = 0;
						}
						if ((wpmgr.wp_flag & WPDL.KICK_DL) != 0) {
							wpmgr.wp_flag &= ~WPDL.KICK_DL;
							start_download();
						}
						break;
                    case "gps_min_sats":
                        msats = raw[0];
                        MWPLog.message("Received gps_min_sats %u\n", msats);
                        break;
                    case "nav_wp_safe_distance":
                        SEDE.deserialise_u16(raw, out nav_wp_safe_distance);
                        wpdist = nav_wp_safe_distance / 100;
                        MWPLog.message("Received nav_wp_safe_distance %um\n", wpdist);
                        break;
                    case "nav_wp_max_safe_distance":
                        SEDE.deserialise_u16(raw, out nav_wp_safe_distance);
                        wpdist = nav_wp_safe_distance;
                        MWPLog.message("Received nav_wp_max_safe_distance %um\n", wpdist);
                        break;
                case "inav_max_eph_epv":
                        uint32 ift;
                        SEDE.deserialise_u32(raw, out ift);
                            // This stupidity is for Mint ...
                        uint32 *ipt = &ift;
                        float f = *((float *)ipt);
                        inav_max_eph_epv = (uint16)f;
                        MWPLog.message("Received (raw) inav_max_eph_epv %u\n",
                                       inav_max_eph_epv);
                        break;
                    case "nav_rth_home_offset_distance":
                        SEDE.deserialise_u16(raw, out nav_rth_home_offset_distance);
                        if(nav_rth_home_offset_distance != 0) {
                            request_common_setting("nav_rth_home_offset_direction");
                        }
                        break;
                    case "nav_rth_home_offset_direction":
                        uint16 odir;
                        SEDE.deserialise_u16(raw, out odir);
                        MWPLog.message("Received home offsets %um / %u°\n",
                                       nav_rth_home_offset_distance/100, odir);
                        break;
                    default:
                        MWPLog.message("Unknown common setting %s\n",
                                       (string)lastmsg.data);
                        break;
                }
                break;

            case MSP.Cmds.STATUS:
                if (xflags == '<') {
                    handle_radar(msp, cmd, raw, len, xflags, errs);
                    return;
                } else {
                    handle_msp_status(raw, len);
                }
                break;
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
				if((wpmgr.wp_flag & WPDL.GETINFO) != 0) {
					string s = "Waypoints in FC\nMax: %u / Mission points: %u Valid: %s".printf(wpi.max_wp, wpi.wp_count, (wpi.wps_valid==1) ? "Yes" : "No");
                    mwp_warning_box(s, Gtk.MessageType.INFO, 5);
					wpmgr.wp_flag &= ~WPDL.GETINFO;
				}
				if ((wpmgr.wp_flag & WPDL.DOWNLOAD) != 0) {
					wpmgr.wp_flag &= ~WPDL.DOWNLOAD;
					download_mission();
				} else if ((wpmgr.wp_flag & WPDL.SET_ACTIVE) != 0) {
					wpmgr.wp_flag &= ~WPDL.SET_ACTIVE;
					if(vi.fc_vers >= FCVERS.hasWP_V4) {
						uint8 msg[128];
						var s = "nav_wp_multi_mission_index";
						var k = 0;
						for(k =0; k < s.length; k++) {
							msg[k] = s.data[k];
						}
						msg[k] = 0;
						msg[k+1] = (uint8)mdx+1;
						MWPLog.message("Set active %d\n", msg[k+1]);
						queue_cmd(MSP.Cmds.COMMON_SET_SETTING, msg, k+2);
					}
				} else if ((wpmgr.wp_flag & WPDL.RESET_POLLER) != 0) {
					wp_reset_poller();
				}
				if(wpi.wp_count > 0 && wpi.wps_valid == 1 && ls.get_list_size() == 0) {
					need_mission = true;
				}
				break;

            case MSP.Cmds.NAV_STATUS:
            case MSP.Cmds.TN_FRAME:
                MSP_NAV_STATUS ns = MSP_NAV_STATUS();
                uint8 flg = 0;
                uint8* rp = raw;
                ns.gps_mode = *rp++;

                if(ns.gps_mode == 15) {
                    if (nticks - last_crit > CRITINTVL) {
                        play_alarm_sound(MWPAlert.GENERAL);
                        MWPLog.message("GPS Critial Failure!!!\n");
                        navstatus.gps_crit();
                        last_crit = nticks;
                    }
                } else
                    last_crit = 0;

                ns.nav_mode = *rp++;
                ns.action = *rp++;
                ns.wp_number = *rp++;
                ns.nav_error = *rp++;

                if(cmd == MSP.Cmds.NAV_STATUS)
                    SEDE.deserialise_u16(rp, out ns.target_bearing);
                else {
                    flg = 1;
                    ns.target_bearing = *rp++;
                }
                navstatus.update(ns,item_visible(DOCKLETS.NAVSTATUS),flg);
                if((replayer & Player.BBOX) == 0 && (NavStatus.nm_pts > 0 && NavStatus.nm_pts != 255)) {
                    if(ns.gps_mode == 3) {
                        if ((conf.osd_mode & OSD.show_mission) != 0) {
                            if (last_nmode != 3 || ns.wp_number != last_nwp) {
                                ls.raise_wp(ns.wp_number);
                                string spt;
                                if(NavStatus.have_rth && ns.wp_number == NavStatus.nm_pts) {
                                    spt = "<span size=\"x-small\">RTH</span>";
                                } else {
                                    StringBuilder sb = new StringBuilder(ns.wp_number.to_string());
                                    if(NavStatus.nm_pts > 0 && NavStatus.nm_pts != 255) {
                                        sb.append_printf("<span size=\"xx-small\">/%u</span>", NavStatus.nm_pts);
                                    }
                                    spt = sb.str;
                                }
                                map_show_wp(spt);
                                mss.m_wp = ns.wp_number;
                                mss.waypoint_changed(mss.m_wp);
                            }
                        }
                        if ((conf.osd_mode & OSD.show_dist) != 0) {
                            show_wp_distance(ns.wp_number);
                        }
                    } else if (last_nmode == 3) {
                        map_hide_wp();
                        mss.m_wp = -1;
                        mss.waypoint_changed(mss.m_wp);
                    }
                }
                last_nmode = ns.gps_mode;
                last_nwp= ns.wp_number;
            break;

            case MSP.Cmds.NAV_POSHOLD:
                have_nc = true;
                MSP_NAV_POSHOLD poscfg = MSP_NAV_POSHOLD();
                uint8* rp = raw;
                poscfg.nav_user_control_mode = *rp++;
                rp = SEDE.deserialise_u16(rp, out poscfg.nav_max_speed);
                rp = SEDE.deserialise_u16(rp, out poscfg.nav_max_climb_rate);
                rp = SEDE.deserialise_u16(rp, out poscfg.nav_manual_speed);
                rp = SEDE.deserialise_u16(rp, out poscfg.nav_manual_climb_rate);
                poscfg.nav_mc_bank_angle = *rp++;
                poscfg.nav_use_midthr_for_althold = *rp++;
                rp = SEDE.deserialise_u16(rp, out poscfg.nav_mc_hover_thr);
                ls.set_mission_speed(poscfg.nav_max_speed / 100.0);
                navconf.mr_update(poscfg);
                if (ls.get_list_size() > 0)
                    ls.calc_mission();
                break;

            case MSP.Cmds.FW_CONFIG:
                have_nc = true;
                MSP_FW_CONFIG fw = MSP_FW_CONFIG();
                uint8* rp = raw;
                rp = SEDE.deserialise_u16(rp, out fw.cruise_throttle);
                rp = SEDE.deserialise_u16(rp, out fw.min_throttle);
                rp = SEDE.deserialise_u16(rp, out fw.max_throttle);
                fw.max_bank_angle = *rp++;
                fw.max_climb_angle = *rp++;
                fw.max_dive_angle = *rp++;
                fw.pitch_to_throttle = *rp++;
                rp = SEDE.deserialise_u16(rp, out fw.loiter_radius);
                navconf.fw_update(fw);
                break;

            case MSP.Cmds.NAV_CONFIG:
                have_nc = true;
                MSP_NAV_CONFIG nc = MSP_NAV_CONFIG();
                uint8* rp = raw;
                nc.flag1 = *rp++;
                nc.flag2 = *rp++;
                rp = SEDE.deserialise_u16(rp, out nc.wp_radius);
                rp = SEDE.deserialise_u16(rp, out nc.safe_wp_distance);
                rp = SEDE.deserialise_u16(rp, out nc.nav_max_altitude);
                rp = SEDE.deserialise_u16(rp, out nc.nav_speed_max);
                rp = SEDE.deserialise_u16(rp, out nc.nav_speed_min);
                nc.crosstrack_gain = *rp++;
                rp = SEDE.deserialise_u16(rp, out nc.nav_bank_max);
                rp = SEDE.deserialise_u16(rp, out nc.rth_altitude);
                nc.land_speed = *rp++;
                rp = SEDE.deserialise_u16(rp, out nc.fence);
                wp_max = nc.max_wp_number = *rp;
                navconf.mw_update(nc);
                ls.set_mission_speed(nc.nav_speed_max / 100.0);
                if (ls.get_list_size() > 0)
                    ls.calc_mission();
                break;

            case MSP.Cmds.SET_NAV_CONFIG:
                MWPLog.message("RX set nav config\n");
                queue_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
                break;

            case MSP.Cmds.COMP_GPS:
                MSP_COMP_GPS cg = MSP_COMP_GPS();
                uint8* rp;
                rp = SEDE.deserialise_u16(raw, out cg.range);
                rp = SEDE.deserialise_i16(rp, out cg.direction);
                cg.update = *rp;
                navstatus.comp_gps(cg,item_visible(DOCKLETS.NAVSTATUS));
                break;

            case MSP.Cmds.ATTITUDE:
                MSP_ATTITUDE at = MSP_ATTITUDE();
                uint8* rp;
                rp = SEDE.deserialise_i16(raw, out at.angx);
                rp = SEDE.deserialise_i16(rp, out at.angy);
                SEDE.deserialise_i16(rp, out at.heading);
                if (usemag || ((replayer & Player.MWP) == Player.MWP)) {
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
                rp = SEDE.deserialise_i32(raw, out al.estalt);
                SEDE.deserialise_i16(rp, out al.vario);
                navstatus.set_altitude(al, item_visible(DOCKLETS.NAVSTATUS));
                vabox.update(item_visible(DOCKLETS.VBOX), al.vario);
                break;

            case MSP.Cmds.ANALOG2:
                MSP_ANALOG an = MSP_ANALOG();
                uint16 v;
                uint32 pmah;
                SEDE.deserialise_u16(raw+1, out v);
                SEDE.deserialise_u16(raw+3, out an.amps);
                SEDE.deserialise_u32(raw+9, out pmah);
                an.powermetersum = (uint16)pmah;
                SEDE.deserialise_u16(raw+22, out an.rssi);
                an.vbat = v / 10;
                process_msp_analog(an);
                break;

            case MSP.Cmds.ANALOG:
                MSP_ANALOG an = MSP_ANALOG();
                an.vbat = raw[0];
                SEDE.deserialise_u16(raw+1, out an.powermetersum);
                SEDE.deserialise_i16(raw+3, out an.rssi);
                SEDE.deserialise_i16(raw+5, out an.amps);
                process_msp_analog(an);
                break;

            case MSP.Cmds.RAW_GPS:
                if (xflags == '<') {
                    handle_radar(msp, cmd, raw, len, xflags, errs);
                } else {
					MSP_RAW_GPS rg = MSP_RAW_GPS();
					uint8* rp = raw;
					rg.gps_fix = *rp++;
					if(rg.gps_fix != 0) {
						if(replayer == Player.NONE) {
							if(inav)
								rg.gps_fix++;
						} else {
							last_gps = nticks;
						}
					}
					flash_gps();

					rg.gps_numsat = *rp++;
					rp = SEDE.deserialise_i32(rp, out rg.gps_lat);
					rp = SEDE.deserialise_i32(rp, out rg.gps_lon);
					rp = SEDE.deserialise_i16(rp, out rg.gps_altitude);
					rp = SEDE.deserialise_u16(rp, out rg.gps_speed);
					rp = SEDE.deserialise_u16(rp, out rg.gps_ground_course);
					if(len == 18) {
						SEDE.deserialise_u16(rp, out rg.gps_hdop);
						rhdop = rg.gps_hdop;
						gpsinfo.set_hdop(rg.gps_hdop/100.0);
					}
					double ddm;

					if(fakeoff.faking) {
						rg.gps_lat += (int32)(fakeoff.dlat*10000000);
						rg.gps_lon += (int32)(fakeoff.dlon*10000000);
					}

					gpsfix = (gpsinfo.update(rg, conf.dms, item_visible(DOCKLETS.GPS),out ddm) != 0);
					fbox.update(item_visible(DOCKLETS.FBOX));
					dbox.update(item_visible(DOCKLETS.DBOX));
					_nsats = rg.gps_numsat;

					if (gpsfix) {
						if (vi.fc_api >= APIVERS.mspV2 && vi.fc_vers >= FCVERS.hasTZ) {
							if(rtcsecs == 0 && _nsats >= msats && replayer == Player.NONE) {
								MWPLog.message("Request RTC pos: %f %f sats %d hdop %.1f\n",
											   GPSInfo.lat, GPSInfo.lon,
											   _nsats, rhdop/100.0);
								queue_cmd(MSP.Cmds.RTC,null, 0);
							}
						}

						sat_coverage();
						if(armed == 1) {
							var spd = (double)(rg.gps_speed/100.0);
							update_odo(spd, ddm);
							if(have_home == false && home_changed(wp0.lat, wp0.lon)) {
								sflags |=  NavStatus.SPK.GPS;
								want_special |= POSMODE.HOME;
								navstatus.cg_on();
							}
						}

						if(craft != null) {
							update_pos_info();
						}
						if(want_special != 0) {
							process_pos_states(GPSInfo.lat,GPSInfo.lon, rg.gps_altitude, "RAW GPS");
						}
					}
				}
                break;

            case MSP.Cmds.SET_WP:
                if(wpmgr.wps.length > 0) {
					lastok = lastrx = nticks;
					wpmgr.wpidx++;
					if(wpmgr.wpidx < wpmgr.npts) {
						uint8 wtmp[32];
						var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
						validatelab.set_text("WP:%3d".printf(wpmgr.wpidx+1));
						queue_cmd(MSP.Cmds.SET_WP, wtmp, nb);
					} else {
                        MWPLog.message("DBG: WP Flag %s\n", wpmgr.wp_flag.to_string());
                        MWPCursor.set_normal_cursor(window);
						remove_tid(ref upltid);

						if((wpmgr.wp_flag & WPDL.CALLBACK) != 0)
							upload_callback(wpmgr.npts);

						if ((wpmgr.wp_flag & WPDL.SAVE_EEPROM) != 0) {
							uint8 zb=42;
							wpmgr.wp_flag = (WPDL.GETINFO|WPDL.RESET_POLLER|WPDL.SET_ACTIVE|WPDL.SAVE_ACTIVE);
							queue_cmd(MSP.Cmds.WP_MISSION_SAVE, &zb, 1);
						} else if ((wpmgr.wp_flag & WPDL.GETINFO) != 0) {
							wpmgr.wp_flag |= WPDL.SET_ACTIVE|WPDL.RESET_POLLER;
                            if(inav)
                                queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
                            else
                                wpmgr.wp_flag = WPDL.RESET_POLLER;
                                wp_reset_poller();
                            validatelab.set_text("✔"); // u+2714
							mwp_warning_box("Mission uploaded", Gtk.MessageType.INFO,5);
						} else if ((wpmgr.wp_flag & WPDL.FOLLOW_ME) !=0 ) {
                            request_wp(254);
                            wpmgr.wp_flag &= ~WPDL.FOLLOW_ME;
                            wp_reset_poller();
                        } else {
							wp_reset_poller();
						}
					}
                }
                break;

            case MSP.Cmds.WP:
                handle_mm_download(raw, len);
                break;

            case MSP.Cmds.SAFEHOME:
                uint8* rp = raw;
                uint8 id = *rp++;
                SafeHome shm = SafeHome();
                shm.enabled = (*rp == 1) ? true : false;
                rp++;
                int32 ll;
                rp = SEDE.deserialise_i32(rp, out ll);
                shm.lat = ll / 10000000.0;
                SEDE.deserialise_i32(rp, out ll);
                shm.lon = ll / 10000000.0;
                safehomed.receive_safehome(id, shm);
                id += 1;
                if (id < 8 && id <= last_safehome)
                    queue_cmd(MSP.Cmds.SAFEHOME,&id,1);
                break;

		    case MSP.Cmds.SET_SAFEHOME:
                safeindex += 1;
                msp_publish_home(safeindex);
                break;

            case MSP.Cmds.WP_MISSION_SAVE:
                MWPLog.message("Confirmed mission save\n");
				if ((wpmgr.wp_flag & WPDL.GETINFO) != 0) {
                    if(inav)
                        queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
					validatelab.set_text("✔"); // u+2714
					mwp_warning_box("Mission uploaded", Gtk.MessageType.INFO,5);
				}
                break;

            case MSP.Cmds.EEPROM_WRITE:
                MWPLog.message("Wrote EEPROM\n");
				if ((wpmgr.wp_flag & WPDL.RESET_POLLER) != 0) {
					wp_reset_poller();
				}
                break;

            case MSP.Cmds.RADIO:
                if(!ignore_3dr) {
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
                rp = SEDE.deserialise_i32(raw, out of.lat);
                rp = SEDE.deserialise_i32(rp, out of.lon);
                rp = SEDE.deserialise_i32(rp, out of.alt);
                of.fix = raw[13];
                wp0.lat = of.lat/10000000.0;
                wp0.lon = of.lon/10000000.0;
                double ofalt = of.alt/100.0;

                if(fakeoff.faking) {
                    wp0.lat += fakeoff.dlat;
                    wp0.lon += fakeoff.dlon;
                }
                if(home_changed(wp0.lat, wp0.lon)) {
                    if(of.fix == 0) {
                        no_ofix++;
                    } else {
                        navstatus.cg_on();
                        sflags |=  NavStatus.SPK.GPS;
                        want_special |= POSMODE.HOME;
                        process_pos_states(wp0.lat, wp0.lon, ofalt, "LTM OFrame");
                    }
                }
                if(Logger.is_logging) {
                    Logger.ltm_oframe(of);
                }
                break;

            case MSP.Cmds.TG_FRAME:
                sflags |=  NavStatus.SPK.ELEV;
                LTM_GFRAME gf = LTM_GFRAME();
                uint8* rp;

                flash_gps();
                last_gps = nticks;

                rp = SEDE.deserialise_i32(raw, out gf.lat);
                rp = SEDE.deserialise_i32(rp, out gf.lon);
                if(fakeoff.faking) {
                    gf.lat += (int32)(fakeoff.dlat*10000000);
                    gf.lon += (int32)(fakeoff.dlon*10000000);
                }

                gf.speed = *rp++;
                rp = SEDE.deserialise_i32(rp, out gf.alt);
                gf.sats = *rp;
                init_craft_icon();
                MSP_ALTITUDE al = MSP_ALTITUDE();
                al.estalt = gf.alt;
                al.vario =  calc_vario(gf.alt);
                navstatus.set_altitude(al, item_visible(DOCKLETS.NAVSTATUS));
                vabox.update(item_visible(DOCKLETS.VBOX), al.vario);

                double ddm;
                int fix = gpsinfo.update_ltm(gf, conf.dms, item_visible(DOCKLETS.GPS), rhdop, out ddm);
                _nsats = (gf.sats >> 2);

                if((_nsats == 0 && nsats != 0) || (nsats == 0 && _nsats != 0)) {
                    nsats = _nsats;
                    navstatus.sats(_nsats, true);
                }

                if(fix > 0) {
                    sat_coverage();
                    if(armed != 0) {
                        if(have_home) {
                            if(_nsats >= msats || ltm_force_sats) {
                                if(pos_valid(GPSInfo.lat, GPSInfo.lon)) {
                                    double dist,cse;
                                    Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                                                home_pos.lat, home_pos.lon,
                                                out dist, out cse);
                                    if(dist < 256) {
                                        var cg = MSP_COMP_GPS();
                                        cg.range = (uint16)Math.lround(dist*1852);
                                        cg.direction = (int16)Math.lround(cse);
                                        navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
                                        update_odo((double)gf.speed, ddm);
                                    }
                                }
                            }
                        } else {
                            if(no_ofix == 10) {
                                MWPLog.message("No home position yet\n");
                            }
                        }
                        if((sensor & MSP.Sensors.MAG) == MSP.Sensors.MAG
                           && last_nmode != 3 && magcheck && magtime > 0 && magdiff > 0) {
                            int gcse = (int)GPSInfo.cse;
                            if(last_ltmf != MSP.LTM.poshold && last_ltmf != MSP.LTM.land) {
                                if(gf.speed > 3) {
                                    if(get_heading_diff(gcse, mhead) > magdiff) {
                                        if(magdt == -1) {
                                            magdt = (int)duration;
//                                            MWPLog.message("set mag %d %d %d\n", mhead, (int)gcse, magdt);
                                        }
                                    } else if (magdt != -1) {
//                                        MWPLog.message("clear magdt %d %d %d\n", mhead, (int)gcse, magdt);
                                        magdt = -1;
										map_hide_warning();

                                    }
								} else if (magdt != -1) {
                                    magdt = -1;
//									MWPLog.message("unset magdt %d %d %d\n", mhead, (int)gcse, magdt);
									map_hide_warning();

								}
                            }
                            if(magdt != -1 && ((int)duration - magdt) > magtime) {
                                MWPLog.message(" ****** Heading anomaly detected %d %d %d\n",
                                               mhead, (int)gcse, magdt);
                                map_show_warning("HEADING ANOMALY");
                                play_alarm_sound(MWPAlert.RED);
                                magdt = -1;
                            }
                        }
                    }

                    if(craft != null && fix > 0 && (_nsats >= msats || ltm_force_sats)) {
                        update_pos_info();
                    }

                    if(want_special != 0)
                        process_pos_states(GPSInfo.lat, GPSInfo.lon, gf.alt/100.0, "GFrame");
                }
                fbox.update(item_visible(DOCKLETS.FBOX));
                dbox.update(item_visible(DOCKLETS.DBOX));
				break;

            case MSP.Cmds.TX_FRAME:
                uint8* rp;
                LTM_XFRAME xf = LTM_XFRAME();
                rp = SEDE.deserialise_u16(raw, out rhdop);
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
                LTM_AFRAME af = LTM_AFRAME();
                uint8* rp;
                rp = SEDE.deserialise_i16(raw, out af.pitch);
                rp = SEDE.deserialise_i16(rp, out af.roll);
                rp = SEDE.deserialise_i16(rp, out af.heading);
                var h = af.heading;
                if(h < 0)
                    h += 360;
                mhead = h;
                navstatus.update_ltm_a(af, item_visible(DOCKLETS.NAVSTATUS));
                art_win.update(af.roll*10, af.pitch*10, item_visible(DOCKLETS.ARTHOR));
				break;

            case MSP.Cmds.TS_FRAME:
                LTM_SFRAME sf = LTM_SFRAME ();
                uint8* rp;
                rp = SEDE.deserialise_u16(raw, out sf.vbat);
                rp = SEDE.deserialise_u16(rp, out sf.vcurr);
                sf.rssi = *rp++;
                sf.airspeed = *rp++;
                sf.flags = *rp++;
                radstatus.update_ltm(sf,item_visible(DOCKLETS.RADIO));

                uint8 ltmflags = sf.flags >> 2;
                uint64 mwflags = 0;
                uint8 saf = sf.flags & 1;
                bool failsafe = ((sf.flags & 2)  == 2);

                if(xfailsafe != failsafe) {
                    if(failsafe) {
                        MWPLog.message("Failsafe asserted %ds\n", duration);
                        map_show_warning("FAILSAFE");
                    } else {
                        MWPLog.message("Failsafe cleared %ds\n", duration);
                        map_hide_warning();
                    }
                    xfailsafe = failsafe;
                }

                if ((saf & 1) == 1) {
                    mwflags = arm_mask;
                    armed = 1;
                    dac = 0;
                } else {
                    dac++;
                    if(dac == 1 && armed != 0) {
                        MWPLog.message("Assumed disarm from LTM %ds\n", duration);
                        mwflags = 0;
                        armed = 0;
                        init_have_home();
                        /* schedule the bubble machine again .. */
                        if(replayer == Player.NONE) {
                            reset_poller();
                        }
                    }
                }
                if(ltmflags == MSP.LTM.angle)
                    mwflags |= angle_mask;
                if(ltmflags == MSP.LTM.horizon)
                    mwflags |= horz_mask;
                if(ltmflags == MSP.LTM.poshold)
                    mwflags |= ph_mask;
                if(ltmflags == MSP.LTM.waypoints)
                    mwflags |= wp_mask;
                if(ltmflags == MSP.LTM.rth || ltmflags == MSP.LTM.land)
                    mwflags |= rth_mask;
                else
                    mwflags = xbits; // don't know better

                var achg = armed_processing(mwflags,"ltm");
                var xws = want_special;
                var mchg = (ltmflags != last_ltmf);
                if(mchg) {
                    last_ltmf = ltmflags;
                    if(ltmflags == MSP.LTM.poshold)
                        want_special |= POSMODE.PH;
                    else if(ltmflags == MSP.LTM.waypoints) {
                        want_special |= POSMODE.WP;
                        if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
                            NavStatus.nm_pts = last_wp_pts;
                    } else if(ltmflags == MSP.LTM.rth)
                        want_special |= POSMODE.RTH;
                    else if(ltmflags == MSP.LTM.althold)
                        want_special |= POSMODE.ALTH;
                    else if(ltmflags == MSP.LTM.cruise)
                        want_special |= POSMODE.CRUISE;
					else if (ltmflags == MSP.LTM.undefined)
						want_special |= POSMODE.UNDEF;
                    else if(ltmflags != MSP.LTM.land) {
                        if(craft != null)
                            craft.set_normal();
                    }
                    var lmstr = MSP.ltm_mode(ltmflags);
                    MWPLog.message("New LTM Mode %s (%d) %d %ds %f %f %x %x\n",
                                   lmstr, ltmflags, armed, duration,
                                   xlat, xlon, xws, want_special);
                    fmodelab.set_label(lmstr);
                }

                if(mchg || achg)
                    update_mss_state(ltmflags);

                if(want_special != 0 /* && have_home*/)
                    process_pos_states(xlat,xlon, 0, "SFrame");

                uint16 mah = sf.vcurr;
                uint16 ivbat = (sf.vbat + 50) / 100;
//                stderr.printf("TS/a frame %u %.1f mah=%u r=%d\n", curr.bbla, ((double)curr.bbla)/100.0,mah, replayer);
                if ((replayer & Player.BBOX) == Player.BBOX && curr.bbla > 0) {
                    curr.ampsok = true;
                    curr.centiA = curr.bbla;
                    if (mah > curr.mah)
                        curr.mah = mah;
                    navstatus.current(curr, 2);
                        // already checked for odo with bbl amps
                } else if (replayer == Player.MWP_FAST || replayer == Player.OTX_FAST) {
                    curr.ampsok = true;
                    curr.mah = mah;
                    navstatus.current(curr, 2);
                } else if (curr.lmah == 0) {
                    curr.lmahtm = nticks;
                    curr.lmah = mah;
                } else if (mah > 0 && mah != 0xffff) {
                    if (mah > curr.lmah) {
                        var mahtm = nticks;
                        var tdiff = (mahtm - curr.lmahtm);
                        var cdiff = mah - curr.lmah;
                            // should be time aware
                        if(cdiff < 100 || curr.lmahtm == 0) {
                            curr.ampsok = true;
                            curr.mah = mah;
                            var iamps = (uint16)(cdiff * 3600 / tdiff);
                                if (iamps >=  0 && tdiff > 5) {
                                    curr.centiA = iamps;
                                    navstatus.current(curr, 2);
                                    if (curr.centiA > odo.amps)
                                        odo.amps = curr.centiA;
                                    curr.lmahtm = mahtm;
                                    curr.lmah = mah;
                                }
                        } else {
                            MWPLog.message("curr error %d\n",cdiff);
                        }
                        curr.lmahtm = mahtm;
                        curr.lmah = mah;
                    }
                    else if (curr.lmah - mah > 100) {
                        MWPLog.message("Negative energy usage %u %u\n", curr.lmah, mah);
                    }
                }
                navstatus.update_ltm_s(sf, item_visible(DOCKLETS.NAVSTATUS));
                set_bat_stat(ivbat);
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_HEARTBEAT:
                Mav.MAVLINK_HEARTBEAT m = *(Mav.MAVLINK_HEARTBEAT*)raw;
                force_mav = false;

                if(craft == null) {
                    Mav.mav2mw(m.type);
                    init_craft_icon();
                }

                if ((m.base_mode & 128) == 128)
                    armed = 1;
                else
                    armed = 0;
                sensor = mavsensors;

                var achg = armed_processing(armed,"mav");
                uint8 ltmflags = (vi.fc_vers >= FCVERS.hasPOI) ?
                    Mav.mav2inav(m.custom_mode, (m.type == Mav.TYPE.MAV_TYPE_FIXED_WING)) :
                    Mav.xmav2inav(m.custom_mode, (m.type == Mav.TYPE.MAV_TYPE_FIXED_WING));

                var mchg = (ltmflags != last_ltmf);
                if (mchg) {
                    last_ltmf = ltmflags;
                    if(ltmflags == MSP.LTM.poshold)
                        want_special |= POSMODE.PH;
                    else if(ltmflags == MSP.LTM.waypoints)
                        want_special |= POSMODE.WP;
                    else if(ltmflags == MSP.LTM.rth)
                        want_special |= POSMODE.RTH;
                    else if(ltmflags == MSP.LTM.althold)
                        want_special |= POSMODE.ALTH;
                    else if(ltmflags == MSP.LTM.cruise)
                        want_special |= POSMODE.CRUISE;
                    else if(ltmflags != MSP.LTM.land) {
                        if(craft != null)
                            craft.set_normal();
                    }
                }

                if(achg || mchg)
                    update_mss_state(ltmflags);

                if(Logger.is_logging)
                    Logger.mav_heartbeat(m);
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_SYS_STATUS:
                Mav.MAVLINK_SYS_STATUS m = *(Mav.MAVLINK_SYS_STATUS*)raw;
                if(sflags == 1) {
                    mavsensors = 1;
                    if((m.onboard_control_sensors_health & 0x8) == 0x8) {
                        sflags |= NavStatus.SPK.BARO;
                        mavsensors |= MSP.Sensors.BARO;
                    }
                    if((m.onboard_control_sensors_health & 0x20) == 0x20) {
                        sflags |= NavStatus.SPK.GPS;
                        mavsensors |= MSP.Sensors.GPS;
                    }
                    if((m.onboard_control_sensors_health & 0x4)== 0x4) {
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
				usemag = (m.cog == 0xffff);
                var fix  = gpsinfo.update_mav_gps(m, conf.dms,
                                                  item_visible(DOCKLETS.GPS), out ddm);
                gpsfix = (fix > 1);
                _nsats = m.satellites_visible;

                if(gpsfix) {
                    sat_coverage();
                    if(armed == 1) {
                        if(m.vel != 0xffff) {
                            update_odo(m.vel/100.0, ddm);
                        }

                        if(have_home == false) {
                            sflags |=  NavStatus.SPK.GPS;
                            navstatus.cg_on();
							home_changed(GPSInfo.lat, GPSInfo.lon);
							want_special |= POSMODE.HOME;
                        } else {
                            double dist,cse;
                            Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                                        home_pos.lat, home_pos.lon,
                                        out dist, out cse);
							if(dist >= 0.0 && dist < 150) {
								var cg = MSP_COMP_GPS();
								cg.range = (uint16)Math.lround(dist*1852);
								cg.direction = (int16)Math.lround(cse);
								navstatus.comp_gps(cg, item_visible(DOCKLETS.NAVSTATUS));
							}
						}
                    }
                    if(craft != null) {
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
				mhead = (int16)(m.yaw*RAD2DEG);
				if(mhead < 0)
					mhead += 360;
                navstatus.set_mav_attitude(m,item_visible(DOCKLETS.NAVSTATUS));
                art_win.update((int16)(m.roll*57.29578*10), -(int16)(m.pitch*57.29578*10),
                               item_visible(DOCKLETS.ARTHOR));
                break;

            case MSP.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW:
                Mav.MAVLINK_RC_CHANNELS m = *(Mav.MAVLINK_RC_CHANNELS*)raw;
                var mrssi = m.rssi*1023/255;
                radstatus.update_rssi(mrssi,item_visible(DOCKLETS.RADIO));
                if (Logger.is_logging) {
                    Logger.mav_rc_channels(m);
                }
                break;

            case MSP.Cmds.MAVLINK_MSG_GPS_GLOBAL_ORIGIN:
                Mav. MAVLINK_GPS_GLOBAL_ORIGIN m = *(Mav.MAVLINK_GPS_GLOBAL_ORIGIN *)raw;
                wp0.lat  = m.latitude / 10000000.0;
                wp0.lon  = m.longitude / 10000000.0;

                if(home_changed(wp0.lat, wp0.lon)) {
                    navstatus.cg_on();
                    sflags |=  NavStatus.SPK.GPS;
                    want_special |= POSMODE.HOME;
                    process_pos_states(wp0.lat, wp0.lon, m.altitude / 1000.0, "MAvOrig");
                }

                if(Logger.is_logging) {
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
                        if(!msp.available && !autocon) {
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
//                stderr.printf("Ta frame %u %.1f\n", val, ((double)val)/100.0);
				if (curr.bbla > odo.amps)
					odo.amps = curr.bbla;
                break;

            case MSP.Cmds.Tr_FRAME:
                uint8* rp;
				int16 ail,ele,rud,thr;
                rp = SEDE.deserialise_i16(raw, out ail);
                rp = SEDE.deserialise_i16(rp, out ele);
                rp = SEDE.deserialise_i16(rp, out rud);
                SEDE.deserialise_i16(rp, out thr);
//                stderr.printf("DBG: Tr frame a:%d e:%d r:%d t:%d\n", ail, ele, rud, thr);
				sticks.update(ail, ele, rud, thr);
				break;

            case MSP.Cmds.Tx_FRAME:
                MWPLog.message("Replay disarm %s (%u)\n", MSP.bb_disarm(raw[0]), raw[0]);
                cleanup_replay();
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
				wpmgr.wp_flag = WPDL.DOWNLOAD;
                queue_cmd(MSP.Cmds.WP_GETINFO, null, 0);
                break;

            case MSP.Cmds.SET_RTC:
                MWPLog.message("Set RTC ack\n");
                break;

            case MSP.Cmds.DEBUGMSG:
				var dstr = ((string)raw).chomp();
				MWPLog.message("DEBUG:%s\n", dstr);
                break;

            case MSP.Cmds.RADAR_POS:
            case MSP.Cmds.COMMON_SET_RADAR_POS:
                process_inav_radar_pos(raw, len);
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_OWNSHIP:
//                dump_mav_os_msg(raw);
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_TRAFFIC_REPORT:
                process_mavlink_radar(raw);
                break;

            case MSP.Cmds.MAVLINK_MSG_ID_DATA_REQUEST:
            case MSP.Cmds.MAVLINK_MSG_ID_STATUS:
                break;

            case MSP.Cmds.MAVLINK_MSG_SCALED_PRESSURE:
                break;

            case MSP.Cmds.MAVLINK_MSG_BATTERY_STATUS:
                int32 mavmah;
                int16 mavamps;

                SEDE.deserialise_i32(raw, out mavmah);
                SEDE.deserialise_i16(&raw[30], out mavamps);
                curr.centiA = mavamps;
                curr.mah = mavmah;
                if(curr.centiA != 0 || curr.mah != 0) {
                    curr.ampsok = true;
                    navstatus.current(curr, 2);
                    if (curr.centiA > odo.amps)
                        odo.amps = curr.centiA;
                }
                break;

            case MSP.Cmds.MAVLINK_MSG_STATUSTEXT:
				uint8 sev = raw[0];
				raw[51] = 0;
				string text = (string)raw[1:50];
				var stext = text.strip();
				MWPLog.message("mavstatus (%d) %s\n", sev, stext);
                break;

            default:
                uint mcmd;
                string mtxt;
                if (cmd < MSP.Cmds.LTM_BASE) {
                    mcmd = cmd;
                    mtxt = "MSP";
                }
                else if (cmd >= MSP.Cmds.LTM_BASE && cmd < MSP.Cmds.MAV_BASE) {
                    mcmd = cmd - MSP.Cmds.LTM_BASE;
                    mtxt = "LTM";
                } else {
                    mcmd = cmd - MSP.Cmds.MAV_BASE;
                    mtxt = "MAVLink";
                }

                StringBuilder sb = new StringBuilder("** Unknown ");
                sb.printf("%s : %u / 0x%x (%ubytes)", mtxt, mcmd, mcmd, len);
                if(len > 0 && conf.dump_unknown) {
                    sb.append(" [");
                    foreach(var r in raw[0:len])
                        sb.append_printf(" %02x", r);
                    sb.append(" ]");
                }
                sb.append_c('\n');
                MWPLog.message (sb.str);
                break;
        }

        if(mq.is_empty() && serstate == SERSTATE.POLLER) {
            if (requests.length > 0)
                tcycle = (tcycle + 1) % requests.length;
            if(tcycle == 0) {
                lastp.stop();
                var et = lastp.elapsed();
                telstats.tot = 0;
                acycle += (uint64)(et*1000);
                anvals++;
                msg_poller();
            } else {
                send_poll();
            }
        }
		run_queue();
    }

    public unowned RadarPlot? find_radar_data(uint id) {
		for(unowned SList<RadarPlot?>lp = radar_plot; lp != null; lp = lp.next) {
			unowned RadarPlot? r = (RadarPlot?)lp.data;
			if (r.id == id) {
				return r;
			}
		}
        return null;
    }

	void decode_sbs(string[] p) {
		bool posrep = (p[1] == "2" || p[1] == "3");
		string s4 = "0x%s".printf(p[4]);
		uint v = (uint)uint64.parse(s4);
		unowned RadarPlot? ri = find_radar_data(v);
		var name = p[10].strip();
		if(ri == null) {
			var r0 = RadarPlot();
			r0.id =  v;
			radar_plot.append(r0);
			ri = find_radar_data(v);
			ri.source = RadarSource.SBS;
			ri.posvalid = false;
			ri.state = 5;
			ri.name = name;
		} else {
			if (name.length > 0)
				ri.name = name;
		}
		if (ri.name == null || ri.name == "")
			ri.name = "[%s]".printf(p[4]);

		if(posrep) {
			double lat = double.parse(p[14]);
			double lng = double.parse(p[15]);
			uint16 hdg = (uint16)int.parse(p[13]);
			int spd = int.parse(p[12]);
			var isvalid = (lat != 0 && lng != 0);
			var currdt = make_sbs_time(p[6], p[7]);
			if ( isvalid && hdg == 0 && spd == 0 && ri.posvalid && ri.dt != null) {
				if (ri.speed == 0.0) {
					double c,d;
					Geo.csedist(ri.latitude, ri.longitude, lat, lng, out d, out c);
					hdg = (uint16)c;
					ri.heading = hdg;
					var tdiff = currdt.difference(ri.dt);
					if (tdiff > 0) {
						ri.speed = d*1852.0 / (tdiff / 1e6) ;
					}
				}
			} else {
				ri.speed = spd * (1852.0/3600.0);
				ri.heading = hdg;
			}
			ri.latitude = lat;
			ri.longitude = lng;
			ri.posvalid = isvalid;
			ri.altitude = int.parse(p[11])*0.3048;
			ri.lasttick = nticks;
			if (isvalid) {
				ri.dt = currdt;
			}
		} else if (p[1] == "4") {
			uint16 hdg = (uint16)int.parse(p[13]);
			int spd = int.parse(p[12]);
			if(spd != 0) {
				ri.speed = spd * (1852.0/3600.0);
			}
			if (hdg != 0) {
				ri.heading = hdg;
			}
		}
		var rdebug = ((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE);
		if(ri.posvalid) {
			markers.update_radar(ref ri);
			if (rdebug) {
				MWPLog.message("SBS p[1]=%s id=%x calls=%s lat=%f lon=%f alt=%.0f hdg=%u speed=%.1f last=%u\n", p[1], ri.id, ri.name, ri.latitude, ri.longitude, ri.altitude, ri.heading, ri.speed, ri.lasttick);
			}
			radarv.update(ref ri, rdebug);
		} else {
			radarv.remove(ri);
			markers.remove_radar(ri);
			radar_plot.remove_all(ri);
		}
	}

	private DateTime make_sbs_time(string d, string t) {
		var p = d.split("/");
#if USE_TV1
		var q = t.split(":");
		return new DateTime.local(int.parse(p[0]), int.parse(p[1]),
								  int.parse(p[2]),
								  int.parse(q[0]), int.parse(q[1]),
								  double.parse(q[2]));
#else
		var ts = "%s-%s-%sT%s+00".printf(p[0], p[1], p[2], t);
		return new DateTime.from_iso8601(ts, null);
#endif
	}

    void process_mavlink_radar(uint8 *rp) {
        var sb = new StringBuilder("MAV radar:");
        uint32 v;
        int32 i;
        uint16 valid;

        SEDE.deserialise_u16(rp+22, out valid);
        SEDE.deserialise_u32(rp, out v);
        sb.append_printf("ICAO %u ", v);
        sb.append_printf("flags: %04x ", valid);
        string callsign = "";
        double lat = 0;
        double lon = 0;

        if ((valid & 0x10) == 0x10) {
            uint8 cs[10];
            uint8 *csp = cs;
            for(var j=0; j < 9; j++) {
                if (*(rp+27+j) != ' ') {
                    *csp++ = *(rp+27+j);
				}
			}
			*csp  = 0;
			callsign = ((string)cs).strip();
			if(callsign.length == 0) {
				callsign = "[%u]".printf(v);
			}
        } else {
            callsign = "[%u]".printf(v);
        }
        sb.append_printf("callsign <%s> ", callsign);

        if ((valid & 1)  == 1) {
            unowned RadarPlot? ri = find_radar_data(v);
            if (ri == null) {
                var r0 = RadarPlot();
                r0.id =  v;
                radar_plot.append(r0);
                ri = find_radar_data(v);
                ri.name = callsign;
                ri.source = RadarSource.MAVLINK;
                ri.posvalid = false;
                sb.append(" * ");
            } else {
                ri.name = callsign;
            }

            SEDE.deserialise_i32(rp+4, out i);
            lat = i / 1e7;
            sb.append_printf("lat %.6f ", lat);

            SEDE.deserialise_i32(rp+8, out i);
            lon = i / 1e7;
            sb.append_printf("lon %.6f ", lon);

            ri.latitude = lat;
            ri.longitude = lon;
            ri.state = 4;
            ri.lasttick = nticks;

            if((valid & 2) == 2) {
                SEDE.deserialise_i32(rp+12, out i);
                var l = i / 1000.0;
                sb.append_printf("alt %.1f ", l);
                ri.altitude = l;
            }

            if((valid & 4) == 4) {
                uint16 h;
                SEDE.deserialise_u16(rp+16, out h);
                sb.append_printf("heading %u ", h);
                ri.heading = h/100;
            }
            if((valid & 8) == 8) {
                uint16 hv;
                SEDE.deserialise_u16(rp+18, out hv);
                ri.speed = hv/100.0;
                sb.append_printf("speed %u ", hv);
            }
            sb.append_printf("tslc %u ", *(rp+37));
            ri.lq = *(rp+37);

            sb.append_printf("ticks %u ", ri.lasttick);
			radarv.update(ref ri, ((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE));
            if(lat != 0 && lon != 0) {
                ri.posvalid = true;
                markers.update_radar(ref ri);
            }
        } else {
            sb.append("invald pos ");
        }

        sb.append_printf("size %u\n", radar_plot.length());
        if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE)
            MWPLog.message(sb.str);
    }

    void process_inav_radar_pos(uint8 []raw, uint len) {
        uint8 *rp = &raw[0];
        int32 ipos;
        uint16 ispd;
        uint8 id = *rp++; // id

        unowned RadarPlot? ri = find_radar_data((uint)id);
        if (ri == null) {
            var r0 = RadarPlot();
            r0.id =  (uint)id;
            radar_plot.append(r0);
            ri = find_radar_data((uint)id);
            ri.name = "⚙ inav %c".printf(65+id);
            ri.source = RadarSource.INAV;
        }
        ri.state = *rp++;
        rp = SEDE.deserialise_i32(rp, out ipos);
        ri.latitude = ((double)ipos)/1e7;
        rp = SEDE.deserialise_i32(rp, out ipos);
        ri.longitude = ((double)ipos)/1e7;
        rp = SEDE.deserialise_i32(rp, out ipos);
        ri.altitude = ipos/100.0;
        rp = SEDE.deserialise_u16(rp, out ri.heading);
        rp = SEDE.deserialise_u16(rp, out ispd);
        ri.speed = ispd/100.0;
        ri.lq = *rp;
        ri.lasttick = nticks;

        radarv.update(ref ri);
        markers.update_radar(ref ri);

        if((debug_flags & DEBUG_FLAGS.RADAR) != DEBUG_FLAGS.NONE) {
            StringBuilder sb = new StringBuilder("RDR-recv:");
            MWPLog.message("RDR-recv %d: Lat, Lon %f %f\n", id, ri.latitude, ri.longitude);
            foreach(var r in raw[0:len])
                sb.append_printf(" %02x", r);
            sb.append_c('\n');
            MWPLog.message(sb.str);
        }
    }

    private void set_typlab() {
        string s;

        if(vname == null || vname.length == 0)
            s = MSP.get_mrtype(vi.mrtype);
        else {
            s = "«%s»".printf(vname);
        }
        typlab.label = s;
    }

    private int get_heading_diff (int a, int b) {
        var d = int.max(a,b) - int.min(a,b);
        if(d > 180)
            d = 360 - d;
        return d;
    }

    private bool lat_lon_diff(double lat0, double lon0, double lat1, double lon1) {
        var d1 = lat0 - lat1;
        var d2 = lon0 - lon1;
        return (((Math.fabs(d1) > 1e-6) || Math.fabs(d2) > 1e-6));
    }

    private bool home_changed(double lat, double lon) {
        bool ret=false;
        if (lat_lon_diff(lat, lon, home_pos.lat , home_pos.lon)) {
            if(have_home && (home_pos.lat != 0.0) && (home_pos.lon != 0.0)) {
                double d,cse;
                Geo.csedist(lat, lon, home_pos.lat, home_pos.lon, out d, out cse);
                d*=1852.0;
                if(d > conf.max_home_delta) {
                    play_alarm_sound(MWPAlert.GENERAL);
                    navstatus.alert_home_moved();
                    MWPLog.message(
                        "Established home has jumped %.1fm [%f %f (ex %f %f)]\n",
                        d, lat, lon, home_pos.lat, home_pos.lon);
                }
            }
            home_pos.lat = wp0.lat = lat;
            home_pos.lon = wp0.lon = lon;
            have_home = true;
            ret = true;
        }
        return ret;
    }

    private void process_pos_states(double lat, double lon, double alt,
                                    string? reason=null) {
        if (lat == 0.0 && lon == 0.0) {
            want_special = 0;
            last_ltmf = 0xff;
            return;
        }

        if((armed != 0) && ((want_special & POSMODE.HOME) != 0)) {
            have_home = true;
            want_special &= ~POSMODE.HOME;
            home_pos.lat = xlat = wp0.lat;
            home_pos.lon = xlon = wp0.lon;
            home_pos.alt = alt;
            markers.add_home_point(wp0.lat,wp0.lon,ls);
            init_craft_icon();
            if(craft != null) {
                if(nrings != 0)
                    markers.initiate_rings(view, lat,lon, nrings, ringint,
                                           conf.rcolstr);
                craft.special_wp(Craft.Special.HOME, wp0.lat, wp0.lon);
            } else {
                init_have_home();
            }

            if(chome)
                map_centre_on(wp0.lat,wp0.lon);

            StringBuilder sb = new StringBuilder ();
            if(reason != null) {
                sb.append(reason);
                sb.append_c(' ');
            }
            sb.append(have_home.to_string());
            MWPLog.message("Set home %f %f (%s)\n", wp0.lat, wp0.lon, sb.str);
            mss.h_lat = wp0.lat;
            mss.h_long = wp0.lon;
            mss.h_alt = (int32)alt;
            mss.home_changed(wp0.lat, wp0.lon, mss.h_alt);

            double dist,cse;
            Geo.csedist(GPSInfo.lat, GPSInfo.lon,
                        home_pos.lat, home_pos.lon,
                        out dist, out cse);

            dist *= 1852;
            if(nav_rth_home_offset_distance > 0 || (dist > 10.0 && dist <= 200.0)) {
                var s = "Home offset %.0fm @ %.0f°".printf(dist, cse);
                map_show_warning(s);
                navstatus.alert_home_offset();
                if(!permawarn)
                    Timeout.add_seconds(15, () => {
                            map_hide_warning();
                            return Source.REMOVE;
                        });
            }
            check_mission_home();
        }

        if((want_special & POSMODE.PH) != 0) {
            if(armed != 0 && msp.available) {
                set_menu_state("followme", true);
            }
            want_special &= ~POSMODE.PH;
            ph_pos.lat = lat;
            ph_pos.lon = lon;
            ph_pos.alt = alt;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.PH, lat, lon);
        } else {
            set_menu_state("followme", false);
        }
        if((want_special & POSMODE.RTH) != 0) {
            want_special &= ~POSMODE.RTH;
            rth_pos.lat = lat;
            rth_pos.lon = lon;
            rth_pos.alt = alt;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.RTH, lat, lon);
        }
        if((want_special & POSMODE.ALTH) != 0) {
            want_special &= ~POSMODE.ALTH;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.ALTH, lat, lon);
        }
        if((want_special & POSMODE.CRUISE) != 0) {
            want_special &= ~POSMODE.CRUISE;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.CRUISE, lat, lon);
        }
        if((want_special & POSMODE.WP) != 0) {
            want_special &= ~POSMODE.WP;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.WP, lat, lon);
            markers.update_ipos(ls, lat, lon);
        }
        if((want_special & POSMODE.UNDEF) != 0) {
            want_special &= ~POSMODE.UNDEF;
            init_craft_icon();
            if(craft != null)
                craft.special_wp(Craft.Special.UNDEF, lat, lon);
            markers.update_ipos(ls, lat, lon);
        }
    }

    private void handle_radio(uint8[] raw) {
        MSP_RADIO r = MSP_RADIO();
        uint8 *rp;
        rp = SEDE.deserialise_u16(raw, out r.rxerrors);
        rp = SEDE.deserialise_u16(rp, out r.fixed_errors);
        r.localrssi = *rp++;
        r.remrssi = *rp++;
        r.txbuf = *rp++;
        r.noise = *rp++;
        r.remnoise = *rp;
        radstatus.update(r,item_visible(DOCKLETS.RADIO));
    }

    private void send_mav_heartbeat() {
        uint8 dummy[9]={0};
        msp.send_mav(0, dummy, 9);
    }

    private void report_bits(uint64 bits) {
        string mode = null;
        if((bits & angle_mask) == angle_mask) {
            mode = "Angle";
        }
        else if((bits & horz_mask) == horz_mask) {
            mode = "Horizon";
        } else if((bits & (ph_mask | rth_mask)) == 0) {
            mode = "Acro";
        }
        if(mode != null) {
            fmodelab.set_label(mode);
            navstatus.update_fmode(mode);
        }
    }

    private size_t serialise_wp(MSP_WP w, uint8[] tmp) {
        uint8* rp = tmp;
        *rp++ = w.wp_no;
        *rp++ = w.action;
        rp = SEDE.serialise_i32(rp, w.lat);
        rp = SEDE.serialise_i32(rp, w.lon);
        rp = SEDE.serialise_i32(rp, w.altitude);
        rp = SEDE.serialise_i16(rp, w.p1);
        rp = SEDE.serialise_i16(rp, w.p2);
        rp = SEDE.serialise_i16(rp, w.p3);
        *rp++ = w.flag;
        return (rp-&tmp[0]);
    }

    public static void play_alarm_sound(string sfn=MWPAlert.RED) {
		if(beep_disabled == false) {
            var fn = MWPUtils.find_conf_file(sfn);
            if(fn != null) {
				AudioPlayer.play(fn);
			}
		}
#if 0
		StringBuilder sb = new StringBuilder();
        sb.assign("Alert: ");
        sb.append(sfn);
        if(sfn == MWPAlert.SAT) {
            sb.append(" (");
            sb.append(nsats.to_string());
            sb.append_c(')');
        }
        sb.append_c('\n');
        MWPLog.message(sb.str);
#endif
    }

    private void init_battery(uint16 ivbat) {
        bat_annul();
        var ncells = ivbat / 37;
        for(var i = 0; i < vcol.levels.length; i++) {
            vcol.levels[i].limit = vcol.levels[i].cell*ncells;
            vcol.levels[i].reached = false;
        }
        vinit = true;
        vwarn1 = 0;
    }

    private void bat_annul() {
        curr = {false,0,0,0,0 ,0};
        for(var i = 0; i < MAXVSAMPLE; i++)
                vbsamples[i] = 0;
        nsampl = 0;
    }

    private void set_bat_stat(uint16 ivbat) {
        if(ivbat < 20) {
            update_bat_indicators(vcol.levels.length-1, 0.0f);
        } else {
            float  vf = ((float)ivbat)/10.0f;
            if (nsampl == MAXVSAMPLE) {
                for(var i = 1; i < MAXVSAMPLE; i++)
                    vbsamples[i-1] = vbsamples[i];
            } else
                nsampl += 1;

            vbsamples[nsampl-1] = vf;
            vf = 0;
            for(var i = 0; i < nsampl; i++)
                vf += vbsamples[i];
            vf /= nsampl;

            if(vinit == false)
                init_battery(ivbat);

            int icol = 0;
            foreach(var v in vcol.levels) {
                if(vf >= v.limit)
                    break;
                icol += 1;
            }

            if (icol > 4)
                icol = 3;

            update_bat_indicators(icol, vf);

            if(vcol.levels[icol].reached == false) {
                vcol.levels[icol].reached = true;
                if(vcol.levels[icol].audio != null) {
                    if(replayer == Player.NONE)
                        play_alarm_sound(vcol.levels[icol].audio);
                    else
                        MWPLog.message("battery alarm %.1f\n", vf);
                }
            }
        }
    }

    private void update_bat_indicators(int icol, float vf) {
        string str;

        if(vcol.levels[icol].label == null) {
            str = "%.1fv".printf(vf);
        } else
            str = vcol.levels[icol].label;

        if(icol != licol)
            licol= icol;

        navstatus.volt_update(str,icol,vf,item_visible(DOCKLETS.VOLTAGE));
    }

	private void upload_mm(int id, WPDL flag) {
		var m = get_mission_data();
		msx[mdx] = m; /* **** FIXME **** */
		var wps = MultiM.missonx_to_wps(msx, id);
		var  mlim = (id == -1) ? msx.length : 1;
		if(wps.length > wp_max || mlim > MAXMULTI) {
			mwp_warning_box(
				"Mission set exceeds FC limits:\nWP: %d/%d\nSegments: %d/%u".printf(wps.length, wp_max, mlim, MAXMULTI), Gtk.MessageType.ERROR);
			return;
		}

		if (wps.length == 0) {
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
		wpmgr.npts = (uint8)wps.length;
        wpmgr.wpidx = 0;
        wpmgr.wps = wps;
        wpmgr.wp_flag = flag;

        serstate = SERSTATE.SET_WP;
        mq.clear();

        MWPCursor.set_busy_cursor(window);
        var timeo = 1500+(wps.length*1000);
        uint8 wtmp[32];
        var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
        queue_cmd(MSP.Cmds.SET_WP, wtmp, nb);
        start_wp_timer(timeo);
	}

    public void start_wp_timer(uint timeo, string reason="WP") {
        upltid = Timeout.add(timeo, () => {
                MWPCursor.set_normal_cursor(window);
                MWPLog.message("%s operation probably failed\n", reason);
                string wmsg = "%s operation timeout.\nThe upload has probably failed".printf(reason);
                mwp_warning_box(wmsg, Gtk.MessageType.ERROR);

                if((wpmgr.wp_flag & WPDL.CALLBACK) != 0)
                    upload_callback(-2);
				reset_poller();
                return Source.REMOVE;
            });
    }

    public void request_wp(uint8 wp) {
        uint8 buf[2];
        have_wp = false;
        buf[0] = wp;
        queue_cmd(MSP.Cmds.WP,buf,1);
    }

    private size_t serialise_nc (MSP_NAV_CONFIG nc, uint8[] tmp) {
        uint8* rp = tmp;

        *rp++ = nc.flag1;
        *rp++ = nc.flag2;

        rp = SEDE.serialise_u16(rp, nc.wp_radius);
        rp = SEDE.serialise_u16(rp, nc.safe_wp_distance);
        rp = SEDE.serialise_u16(rp, nc.nav_max_altitude);
        rp = SEDE.serialise_u16(rp, nc.nav_speed_max);
        rp = SEDE.serialise_u16(rp, nc.nav_speed_min);
        *rp++ = nc.crosstrack_gain;
        rp = SEDE.serialise_u16(rp, nc.nav_bank_max);
        rp = SEDE.serialise_u16(rp, nc.rth_altitude);
        *rp++ = nc.land_speed;
        rp = SEDE.serialise_u16(rp, nc.fence);
        *rp++ = nc.max_wp_number;
        return (rp-&tmp[0]);
    }

    private size_t serialise_pcfg (MSP_NAV_POSHOLD pcfg, uint8[] tmp) {
        uint8* rp = tmp;

        *rp++ = pcfg.nav_user_control_mode;
        rp = SEDE.serialise_u16(rp, pcfg.nav_max_speed);
        rp = SEDE.serialise_u16(rp, pcfg.nav_max_climb_rate);
        rp = SEDE.serialise_u16(rp, pcfg.nav_manual_speed);
        rp = SEDE.serialise_u16(rp, pcfg.nav_manual_climb_rate);
        *rp++ = pcfg.nav_mc_bank_angle;
        *rp++ = pcfg.nav_use_midthr_for_althold;
        rp = SEDE.serialise_u16(rp, pcfg.nav_mc_hover_thr);
        return (rp-&tmp[0]);
    }

    private size_t serialise_fw (MSP_FW_CONFIG fw, uint8[] tmp) {
        uint8* rp = tmp;
        rp = SEDE.serialise_u16(rp, fw.cruise_throttle);
        rp = SEDE.serialise_u16(rp, fw.min_throttle);
        rp = SEDE.serialise_u16(rp, fw.max_throttle);
        *rp++ = fw.max_bank_angle;
        *rp++ = fw.max_climb_angle;
        *rp++ = fw.max_dive_angle;
        *rp++ = fw.pitch_to_throttle;
        rp = SEDE.serialise_u16(rp, fw.loiter_radius);
        return (rp-&tmp[0]);
    }

    private void mw_update_config(MSP_NAV_CONFIG nc) {
        have_nc = false;
        uint8 tmp[64];
        var nb = serialise_nc(nc, tmp);
        queue_cmd(MSP.Cmds.SET_NAV_CONFIG, tmp, nb);
        queue_cmd(MSP.Cmds.NAV_CONFIG,null,0);
    }

    private void mr_update_config(MSP_NAV_POSHOLD pcfg) {
        have_nc = false;
        uint8 tmp[64];
        var nb = serialise_pcfg(pcfg, tmp);
        queue_cmd(MSP.Cmds.SET_NAV_POSHOLD, tmp, nb);
    }

    private void fw_update_config(MSP_FW_CONFIG fw) {
        have_nc = false;
        uint8 tmp[64];
        var nb = serialise_fw(fw, tmp);
        queue_cmd(MSP.Cmds.SET_FW_CONFIG, tmp, nb);
    }

    private void queue_cmd(MSP.Cmds cmd, void* buf, size_t len) {
        if(((debug_flags & DEBUG_FLAGS.INIT) != DEBUG_FLAGS.NONE)
           && (serstate == SERSTATE.NORMAL))
            MWPLog.message("Init MSP %s (%u)\n", cmd.to_string(), cmd);

        if(replayer == Player.NONE) {
            uint8 *dt = (buf == null) ? null : Memory.dup(buf, (uint)len);
            if(msp.available == true) {
                var mi = MQI() {cmd = cmd, len = len, data = dt};
                mq.push_tail(mi);
            }
        }
    }

    private void start_audio(bool live = true) {
        if (spktid == 0) {
            if(audio_on) {
                string voice = null;
                switch(spapi) {
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
                if(live) {
                    gps_alert(0);
                    navstatus.announce(sflags);
                }
            }
        }
    }

    private void stop_audio() {
        if(spktid > 0) {
            remove_tid(ref spktid);
            navstatus.logspeak_close();
        }
    }

    private void remove_tid(ref uint tid) {
        if(tid > 0)
            Source.remove(tid);
        tid = 0;
    }

    private void  gen_serial_stats() {
        if(msp.available)
            telstats.s = msp.dump_stats();
        telstats.avg = (anvals > 0) ? (ulong)(acycle/anvals) : 0;
    }

    private void show_serial_stats() {
        gen_serial_stats();
        MWPLog.message("%.0fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s) to %d wait %d, avg poll loop %lu ms messages %d msg/s %.1f\n",
                       telstats.s.elapsed, telstats.s.rxbytes, telstats.s.txbytes,
                       telstats.s.rxrate, telstats.s.txrate,
                       telstats.toc, telstats.tot, telstats.avg ,
                       telstats.s.msgs, telstats.s.msgs / telstats.s.elapsed);
    }

    private void serial_doom(Gtk.Button c) {
        if(is_shutdown == true)
            return;

		if(xnopoll != nopoll)
			nopoll = xnopoll;
        MWPLog.message("Serial doom replay %d\n", replayer);
        if(inhibit_cookie != 0) {
            uninhibit(inhibit_cookie);
            inhibit_cookie = 0;
            dtnotify.send_notification("mwp", "Unhibit screen/idle/suspend");
            MWPLog.message("Not managing screen / power settings\n");
        }
        map_hide_wp();
        if(replayer == Player.NONE) {
            safehomed.online_change(0);
            arm_warn.hide();
            serstate = SERSTATE.NONE;
            sflags = 0;
            if (conf.audioarmed == true) {
                audio_cb.active = false;
            }
            show_serial_stats();
            if(rawlog == true) {
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
            if (msp.available) {
                msp.close();
                ttrk.enable(msp.get_devname());
            }
#if MQTT
            else if (mqtt_available) {
                mqtt_available = mqtt.mdisconnect();
            }
#endif
            c.set_label("Connect");
            set_mission_menus(false);
            set_menu_state("navconfig", false);
            duration = -1;
            if(craft != null) {
                craft.remove_marker();
            }
            init_have_home();
            set_error_status(null);
            xsensor = 0;
            clear_sensor_array();
        } else {
			if(bbvlist != null) {
				bbvlist = null;
			}
            show_serial_stats();
            if (msp.available)
                msp.close();
            replayer = Player.NONE;
        }
        if(fwddev != null && fwddev.available)
            fwddev.close();

        set_replay_menus(true);
        reboot_status();
    }

    private void clear_mission() {
        ls.clear_mission();
		msx[mdx] = ls.to_mission();
        lastmission=msx_clone();
        last_file = null;
        navstatus.reset_mission();
        FakeHome.usedby &= ~FakeHome.USERS.Mission;
        ls.reset_fake_home();
    }

    private void set_replay_menus(bool state) {
        const string [] ms = {"replay-log","load-log","replay-bb","load-bb",
            "replay-otx","load-otx", "replayraw"};
        var n = 0;
        foreach(var s in ms) {
            var istate = state;
            if( ((n == 2 || n == 3) && x_replay_bbox_ltm_rb == false) ||
                ((n == 4 || n == 5) && x_otxlog == false) ||
                ((n == 6) && x_rawreplay == false))
                istate = false;
            set_menu_state(s, istate);
            n++;
        }
    }

    private void set_mission_menus(bool state) {
        const string[] ms0 = {
			"store-mission",
			"restore-mission",
			"upload-mission",
			"download-mission",
			"navconfig",
			"mission-info"};
        foreach(var s in ms0) {
            set_menu_state(s, state);
		}
		if(vi.fc_vers >= FCVERS.hasWP_V4)
			set_menu_state("upload-missions", state);
	}

    private void init_sstats() {
        if(telstats.s.msgs != 0)
            gen_serial_stats();
        anvals = acycle = 0;
        telstats = {};
        telemstatus.annul();
        radstatus.annul();
    }

    private void init_state() {
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
        Varios.idx = 0;
    }

    private bool try_forwarder(out string fstr) {
        fstr = null;
        if(!fwddev.available) {
            if(fwddev.open_w(forward_device, 0, out fstr) == true) {
                fwddev.set_mode(MWSerial.Mode.SIM);
                MWPLog.message("set forwarder %s\n", forward_device);
            } else {
                MWPLog.message("Forwarder %s\n", fstr);
            }
        }
        return fwddev.available;
    }

    private void dump_radar_db() {
        var dt = new DateTime.now_local ();
        var fn  = "/tmp/radar_%s.log".printf(dt.format("%F_%H%M%S"));
        var fp = FileStream.open(fn,"w");
        if(fp != null) {
			for(unowned SList<RadarPlot?>lp = radar_plot; lp != null; lp = lp.next) {
				//            radar_plot.@foreach ((r) => {
				var r = lp.data;
                    fp.printf("%u\t%s\t%.6f\t%.6f\t%u/%u\t%u\t%u\t%u\t%s\n",
                              r.id, r.name, r.latitude, r.longitude,
                              r.lasttick, nticks, r.state, r.lq,
                              r.source, r.posvalid.to_string());
                }
        }
    }

    private void try_radar_dev() {
		foreach (var r in radardevs) {
			string fstr = null;
			if(!r.dev.available) {
				if(r.dev.open (r.name, 115200, out fstr) == true) {
					MWPLog.message("start radar reader %s\n", r.name);
					if(rawlog)
						r.dev.raw_logging(true);

					if(radartid == -1) {
						radartid = Timeout.add_seconds(300, () => {
								dump_radar_db();
								return Source.CONTINUE;
							});
					}
				} else {
					MWPLog.message("Radar reader %s\n", fstr);
				}
			}
		}
    }

    private void connect_serial() {
		radstatus.set_title(0);
		CRSF.teledata.setlab = false;
		SportDev.active = false;
        map_hide_wp();
        if(msp.available) {
            serial_doom(conbutton);
            markers.remove_rings(view);
            verlab.label = verlab.tooltip_text = "";
            typlab.set_label("");
            statusbar.push(context_id, "");
            set_menu_state("followme", false);
#if MQTT
        } else if (mqtt.available) {
            serial_doom(conbutton);
            markers.remove_rings(view);
            verlab.label = verlab.tooltip_text = "";
            typlab.set_label("");
            statusbar.push(context_id, "");
#endif
        } else {
            var serdev = dev_entry.get_active_text();
            string estr="";
            bool ostat = false;
            if (MwpMisc.is_cygwin()) {
                if (serdev.has_prefix("COM")) {
                    var dnumber = int.parse(serdev[3:serdev.length]);
                    serdev = "/dev/ttyS%d".printf(dnumber-1);
                }
            }

            serstate = SERSTATE.NONE;

            if(lookup_radar(serdev) || serdev == forward_device) {
                mwp_warning_box("The selected device is assigned to a special function (radar / forwarding).\nPlease choose another device", Gtk.MessageType.WARNING, 60);
                return;
            } else if (serdev.has_prefix("mqtt://") ||
                       serdev.has_prefix("ssl://") ||
                       serdev.has_prefix("mqtts://") ||
                       serdev.has_prefix("ws://") ||
                       serdev.has_prefix("wss://") ) {
#if MQTT
                mqtt_available = ostat = mqtt.setup(serdev);
                rawlog = false;
                nopoll = true;
                autocon_cb.active = false;
                serstate = SERSTATE.TELEM;
#else
                mwp_warning_box("MQTT is not enabled in this build\nPlease see the wiki for more information\nhttps://github.com/stronnag/mwptools/wiki/mqtt---bulletgcss-telemetry\n", Gtk.MessageType.WARNING, 60);
                return;
#endif
            } else {
                if (ttrk.is_used(serdev)) {
                    mwp_warning_box("The selected device is use for Telemetry Tracking\n", Gtk.MessageType.WARNING, 60);
                return;
                }
                ttrk.disable(serdev);
                MWPLog.message("Trying OS open for %s\n", serdev);
                ostat = msp.open_w(serdev, conf.baudrate, out estr);
            }

            if (ostat == true) {
                xarm_flags=0xffff;
                lastrx = lastok = nticks;
                init_state();
                init_sstats();
                MWPLog.message("Connected %s %s\n", serdev, nopoll.to_string());
                set_replay_menus(false);
                if(rawlog == true) {
                    msp.raw_logging(true);
                }
                conbutton.set_label("Disconnect");
                if(forward_device != null) {
                    string fstr;
                    if(try_forwarder(out fstr) == false) {
                        uint8 retry = 0;
                        Timeout.add(500, () => {
                                if (!msp.available)
                                    return false;
                                bool ret = !try_forwarder(out fstr);
                                if(ret && retry++ == 5) {
                                    mwp_warning_box(
                                        "Failed to open forwarding device: %s\n".printf(fstr),
                                        Gtk.MessageType.ERROR,10);
                                    ret = false;
                                }
                                return ret;
                            });
                    }
                }
                if (!mqtt_available) {
					var pmask = (MWSerial.PMask)(int.parse(dev_protoc.active_id));
					set_pmask_poller(pmask);
                    msp.setup_reader();
					MWPLog.message("Serial ready\n");
                    if(nopoll == false && !mqtt_available ) {
                        serstate = SERSTATE.NORMAL;
                        queue_cmd(MSP.Cmds.IDENT,null,0);
                        run_queue();
                    } else
                        serstate = SERSTATE.TELEM;
                }
            } else {
                if (autocon == false || autocount == 0) {
                    mwp_warning_box("Unable to open serial device\n%s\nPlease verify you are a member of the owning group\nTypically \"dialout\" or \"uucp\"\n".printf(estr), Gtk.MessageType.WARNING, 60);
                }
                autocount = ((autocount + 1) % 12);
            }
            reboot_status();
        }
    }

    private void anim_cb(bool forced=false) {
        if(pos_is_centre) {
            poslabel.set_text(PosFormat.pos(ly,lx,conf.dms));
            if (map_moved() || forced) {
                if (follow == false && craft != null) {
                    double plat,plon;
                    craft.get_pos(out plat, out plon);
                    var bbox = view.get_bounding_box();
                    if (bbox.covers(plat, plon) == false) {
                        craft.park();
                    }
                }
            }
        }
    }

    private void add_source_combo(string? defmap, MapSource []msources) {
        string[] map_names={};
        var combo  = builder.get_object ("combobox1") as Gtk.ComboBox;
        var map_source_factory = Champlain.MapSourceFactory.dup_default();
        var liststore = new Gtk.ListStore (MS_Column.N_COLUMNS, typeof (string), typeof (string));

        foreach (unowned MapSource s0 in msources) {
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

        foreach (Champlain.MapSourceDesc s in sources) {
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
            if (defmap != null && name == defmap) {
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

        if(defsource == null) {
            defsource = sources.nth_data(0).get_id();
            MWPLog.message("gsettings blank default-map, using %s\n", defsource);
            defval = 0;
        }
        var src = map_source_factory.create_cached_source(defsource);
        view.set_property("map-source", src);

        var cell = new Gtk.CellRendererText();
        combo.pack_start(cell, false);

        combo.add_attribute(cell, "text", 1);
        combo.set_active(defval);
   }

    private bool check_zoom_sanity(double zval) {
        var mmax = view.get_max_zoom_level();
        var mmin = view.get_min_zoom_level();
        var sane = true;
        if (zval > mmax) {
            sane= false;
            view.zoom_level = mmax;
        }
        if (zval < mmin) {
            sane = false;
            view.zoom_level = mmin;
        }
        zoomer.adjustment.value = view.zoom_level;
        return sane;
    }

    public Mission get_mission_data() {
        Mission m = ls.to_mission();
        ls.calc_mission_dist(out m.dist, out m.lt, out m.et);
        m.nspeed = ls.get_mission_speed();
        if (conf.compat_vers != null)
            m.version = conf.compat_vers;
        wp_resp = m.get_ways();
		msx[mdx] = m;
        lastmission = msx_clone();
        return m;
    }

    public void on_file_save() {
        if (last_file == null) {
            on_file_save_as (null);
        } else {
            save_mission_file(last_file);
        }
    }

    private void save_mission_file(string fn, uint mask=0) {
        StringBuilder sb;
        uint8 ftype=0;

        if(fn.has_suffix(".mission") || fn.has_suffix(".xml"))
            ftype = 'm';

        if(fn.has_suffix(".json")) {
            ftype = 'j';
        }

        if(ftype == 0) {
            sb = new StringBuilder(fn);
            if(conf.mission_file_type == "j") {
                ftype = 'j';
                sb.append(".json");
            } else {
                ftype = 'm';
                sb.append(".mission");
            }
            fn = sb.str;
        }

        var m = get_mission_data();

		msx[mdx] = m; /* **** FIXME **** */
		Mission [] mmsx = {};
		for(var j = 0; j < msx.length; j++) {
			if ((mask & (1 << j)) == 0) {
				mmsx += msx[j];
			}
		}
		if (ftype == 'm') {
			XmlIO.to_xml_file(fn, mmsx);
		} else {
            JsonIO.to_json_file(fn, mmsx);
		}
		MissionPix.get_mission_pix(embed, markers, ls.to_mission(), last_file);
    }

    private void check_mission_clean(ActionFunc func, bool cancel = false) {
		msx[mdx] = ls.to_mission();
		var is_dirty = false;
		if (msx.length == lastmission.length) {
			for(var j = 0; j < msx.length; j++) {
				if (!msx[j].is_equal(lastmission[j])) {
					is_dirty = true;
					break;
				}
			}
		} else {
			is_dirty = true;
		}
		if(is_dirty) {
            var dirtyd = new DirtyDialog(cancel);
            dirtyd.response.connect((id) => {
                    switch(id) {
                    case ResponseType.YES:
                        on_file_save_as(func);
                        break;
                    case ResponseType.NO:
                        func();
                        break;
                    default:
                        break;
                    }
                    dirtyd.close();
                });
            dirtyd.show_all();
		} else {
            func();
        }
    }

	private uint check_mission_length(Mission [] xmsx) {
		uint nwp = 0;
		foreach(var m in xmsx) {
			nwp += m.npoints;
		}

		if (nwp == 1 && xmsx[0].get_ways()[0].action == MSP.Action.RTH
			&& xmsx[0].get_ways()[0].flag == 165) {
			nwp = 0;
		}
		return nwp;
	}

    public Mission? open_mission_file(string fn, bool append=false) {
		ms_from_loader = true;
		Mission _ms = null;
		bool is_j = fn.has_suffix(".json");
		var _msx =  (is_j) ? JsonIO.read_json_file(fn) : XmlIO.read_xml_file (fn);
		if (_msx == null)
			return null;

		var nwp = check_mission_length(_msx);
		if (nwp == 0)
			return null;

		if (append) {
			var mlim = msx.length;
			imdx += mlim;
			foreach(var m in _msx) {
				msx += m;
				mlim++;
			}
			if (mlim > MAXMULTI) {
				mwp_warning_box("Mission set count (%d) exceeds firmware maximum of 9.\nYou will not be able to download the whole set to the FC".printf(mlim), Gtk.MessageType.WARNING, 30);
			}
		} else {
			msx = _msx;
			lastmission = msx_clone();
		}

		if (nwp > wp_max) {
			mwp_warning_box("Total number of WP (%u) exceeds firmware maximum (%u).\nYou will not be able to download the whole set to the FC".printf(nwp,wp_max), Gtk.MessageType.WARNING, 30);
		}
		if (msx.length > 0) {
			_ms = setup_mission_from_mm();
		}
		ms_from_loader = false;
		return _ms;
    }

	public Mission? setup_mission_from_mm() {
		Mission m=null;
		mdx = imdx;
		ms_from_loader = true;
		set_act_mission_combo();
		imdx = 0;
		if(msx[mdx] != null && msx[mdx].npoints > 0) {
			m = msx[mdx];
			ls.reset_fake_home();
			NavStatus.nm_pts = (uint8)m.npoints;
			if(fakeoff.faking) {
				for(var i = 0; i < m.npoints; i++) {
					var mi = m.get_waypoint(i);

					if(mi.action != MSP.Action.RTH && mi.action != MSP.Action.JUMP &&  mi.action != MSP.Action.SET_HEAD) {
						mi.lat += fakeoff.dlat;
						mi.lon += fakeoff.dlon;
					}
					m.set_waypoint(mi, i);
				}
				m.cx += fakeoff.dlon;
				m.cy += fakeoff.dlat;
			}
			wp_resp = m.get_ways();
			if (m.homex != 0.0 && m.homey != 0.0) {
				FakeHome.usedby |= FakeHome.USERS.Mission;
				ls.set_fake_home_pos(m.homey, m.homex);
				for(var i = 0; i < m.npoints; i++) {
					var mi = m.get_waypoint(i);
					if (mi.flag == 0x48) {
						mi.lat = m.homey;
						mi.lon = m.homex;
						m.set_waypoint(mi, i);
					}
				}
			}
		} else {
			NavStatus.nm_pts = 255;
			NavStatus.have_rth = false;
			wp_resp ={};
		}
		ms_from_loader = false;
		return m;
	}

    private void on_file_save_as (ActionFunc? func) {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Save to mission file", null, Gtk.FileChooserAction.SAVE,
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
		uint smask = 0;

		if (msx.length > 1) {
			var btn = new Gtk.Button.with_label("Remove segments from file");
			btn.clicked.connect(() => {
					var dialog = new MDialog (msx);
					dialog.remitems.connect((mitem) => {
							smask = mitem;
					});
					dialog.set_transient_for(chooser);
                    dialog.show_all();
				});
			chooser.set_extra_widget(btn);
			btn.show();
		}

        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    last_file = chooser.get_filename ();
                    chooser.destroy ();
                    save_mission_file(last_file, smask);
                    update_title_from_file(last_file);
                } else {
                    chooser.destroy ();
                }
                if(func != null) {
                    func();
                }
            });
		chooser.show();
    }

    private void update_title_from_file(string fname) {
        var basename = GLib.Path.get_basename(fname);
        StringBuilder sb = new StringBuilder("mwp = ");
        sb.append(basename);
        window.title = sb.str;
    }

    private uint guess_appropriate_zoom(Champlain.BoundingBox bb) {
        uint z;

        for(z = view.get_max_zoom_level(); z >= view.get_min_zoom_level(); z--)  {
            var abb =  view.get_bounding_box_for_zoom_level (z);
            if (bb.bottom > abb.bottom && bb.top < abb.top && bb.left > abb.left && bb.right < abb.right)
                break;
        }
        return z;
    }

    private void load_file(string fname, bool warn=true, bool append=false) {
        var ms = open_mission_file(fname, append);
        if(ms != null) {
            last_file = fname;
            update_title_from_file(fname);
        } else if (warn) {
			mwp_warning_box("Failed to open file");
		}
    }

    private void set_view_zoom(uint z) {
        var mmax = view.get_max_zoom_level();
        var mmin = view.get_min_zoom_level();

        if (z < mmin)
            z = mmin;

        if (z > mmax)
            z = mmax;
        view.zoom_level = z;
    }

    private void instantiate_mission(Mission ms) {
        if(armed == 0 && craft != null) {
            markers.remove_rings(view);
            craft.init_trail();
        }
        validatelab.set_text("");
        ls.import_mission(ms, (conf.rth_autoland && Craft.is_mr(vi.mrtype)));
        NavStatus.have_rth = ls.have_rth;
		centre_mission(ms, true);
        if(have_home)
            markers.add_home_point(home_pos.lat,home_pos.lon,ls);
        need_preview = true;
		msx[mdx] = ms;
		validatelab.set_text("✔"); // u+2714
	}

	private Mission?[] msx_clone() {
		Mission? []_lm = {};
		foreach (var m in msx) {
			_lm +=  new Mission.clone(m);
		}
		return _lm;
	}

    private Champlain.BoundingBox bb_from_mission(Mission ms) {
        Champlain.BoundingBox bb = new Champlain.BoundingBox();
        bb.top = ms.maxy;
        bb.bottom = ms.miny;
        bb.right =  ms.maxx;
        bb.left = ms.minx;
        return bb;
    }

    public void mwp_warning_box(string warnmsg,
                                 Gtk.MessageType klass=Gtk.MessageType.WARNING,
                                 int timeout = 0) {
        var msg = new Gtk.MessageDialog.with_markup (window, 0, klass,
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

    private void on_file_open(bool append=false) {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Open a mission file", null, Gtk.FileChooserAction.OPEN,
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

		var scrolled = new Gtk.ScrolledWindow (null, null);
		var bbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
		scrolled.add(bbox);
		var plabel = new Gtk.Label("Select active mission");
        prebox.pack_start (preview, false, false, 1);
        prebox.pack_start (plabel, false, false, 1);
        prebox.pack_start (scrolled, true, true, 1);

        chooser.set_preview_widget(prebox);
        chooser.update_preview.connect (() => {
                string uri = chooser.get_preview_uri ();
                Gdk.Pixbuf pixbuf = null;
                if (uri != null && uri.has_prefix ("file://") == true) {
                    var fn = uri.substring (7);
                    if(!FileUtils.test (fn, FileTest.IS_DIR)) {
						bool is_j = fn.has_suffix(".json");
						var tmpmsx =  (is_j) ? JsonIO.read_json_file(fn) : XmlIO.read_xml_file (fn);
						if (tmpmsx.length > 0) {
							int k = 0;
							mdx = 0;
							Gtk.RadioButton rb0=null, rb=null;
							bbox.foreach ((element) => bbox.remove (element));

							foreach (var m in tmpmsx) {
								k++;
								var sb = new StringBuilder();
								sb.append_printf("Mission Id: %d\nPoints: %u\n", k, m.npoints);
								sb.append_printf("Distance: %.1fm\n", m.dist);
								if (k == 1) {
									rb0 = new Gtk.RadioButton.with_label_from_widget (null, sb.str);
									rb = rb0;
									rb0.set_active(true);
								} else {
									rb = new Gtk.RadioButton.with_label_from_widget (rb0, sb.str);
								}
								bbox.pack_start (rb, false, false, 2);
								rb.toggled.connect((b) => {
										if (b.get_active()) {
											uint8 uidx = b.get_label()[12] - 48;
											imdx = uidx-1;
										}
									});
							}
                        }

                        var ifn = MissionPix.get_cached_mission_image(fn);
                        try {
                            pixbuf = new Gdk.Pixbuf.from_file_at_scale (ifn, 256,
                                                                       256, true);
                        } catch {
                            if (FileUtils.test (fn, FileTest.EXISTS))
                                pixbuf = FlatEarth.getpixbuf(fn, 256, 256);
                        }
                    }
                }

                if(pixbuf != null) {
                    preview.set_from_pixbuf(pixbuf);
                    prebox.show_all ();
                } else
                    prebox.hide ();
            });
        chooser.show_all();
        chooser.modal = false;
        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    var fn = chooser.get_filename ();
                    chooser.destroy ();
                    if(fn != null) {
                        mdx = 0; // Selected item
                        load_file(fn,true,append);
                    }
                } else {
                    chooser.destroy ();
                }
        });
    }

    private void replay_otx(string? fn = null) {
        otx_runner.prepare(fn);
    }

    private void replay_raw(string? fn = null) {
        raw_runner.prepare(fn);
    }

    private void replay_log(bool delay=true) {
        if(thr != null) {
            robj.stop();
        } else {
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

    private void cleanup_replay() {
        if (replayer != Player.NONE) {
			if (sticks.active) {
				Timeout.add_seconds(2, () => {
						sticks.hide();
						return false;
					});
			}
			magcheck = (magtime > 0 && magdiff > 0);
            MWPLog.message("============== Replay complete ====================\n");
            if ((replayer & Player.MWP) == Player.MWP) {
                if(thr != null) {
                    thr.join();
                    thr = null;
                }
            }
            if (is_shutdown)
                return;
            set_replay_menus(true);
            set_menu_state("stop-replay", false);
            if (replayer != Player.OTX && replayer != Player.RAW)
                Posix.close(playfd[1]);
            serial_doom(conbutton);
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
            nopoll = xnopoll;
        }
    }

    private void run_replay(string fn, bool delay, Player rtype,
                            int idx=0, int btype=0, uint8 force_gps=0, uint duration =0) {
        xlog = conf.logarmed;
        xaudio = conf.audioarmed;
        int sr = 0;
        bool rawfd = false;
        xnopoll = nopoll;
        nopoll = true;

        if ((rtype & Player.MWP) != 0 || (rtype & Player.BBOX) != 0 && x_fl2ltm == false) {
            rawfd = true;
        }

        playfd = new int[2];

        if(msp.available)
            serial_doom(conbutton);

        if (rawfd) {
            sr = MwpPipe.pipe(playfd);
        } else {
            sr = msp.randomUDP(playfd);
			set_pmask_poller(MWSerial.PMask.AUTO);
        }

        if(sr == 0) {
            replay_paused = false;
            MWPLog.message("Replay \"%s\" log %s model %d\n",
                           (rtype == Player.OTX) ? "otx" :
                           (rtype == Player.BBOX) ? "bbox" :
                           (rtype == Player.RAW) ? "raw" : "mwp",
                           fn, btype);

            if(craft != null)
                craft.park();

            init_have_home();
            conf.logarmed = false;
            if(delay == false)
                conf.audioarmed = false;

            init_state();
            serstate = SERSTATE.NONE;
            conbutton.sensitive = false;
            update_title_from_file(fn);
            replayer = rtype;
            if(delay == false)
                replayer |= Player.FAST_MASK;

            if(rawfd) {
                msp.open_fd(playfd[0],-1, true);
				set_pmask_poller(MWSerial.PMask.INAV);
			}
            set_replay_menus(false);
            set_menu_state("stop-replay", true);
            magcheck = delay; // only check for normal replays (delay == true)
            switch(replayer) {
            case Player.MWP:
            case Player.MWP_FAST:
                check_mission(fn);
                robj = new ReplayThread();
                thr = robj.run(playfd[1], fn, delay);
                break;
            case Player.BBOX:
            case Player.BBOX_FAST:
                bb_runner.find_bbox_box(fn, idx);
                spawn_bbox_task(fn, idx, btype, delay, force_gps, duration);
                break;
            case Player.RAW:
            case Player.RAW_FAST:
                replayer|= Player.OTX;
                spawn_otx_task(fn, delay, idx, btype, duration);
                break;
            case Player.OTX:
            case Player.OTX_FAST:
                spawn_otx_task(fn, delay, idx, btype, duration);
                break;
            }

			if ((rtype & (Player.BBOX|Player.OTX)) != 0) {
				if (sticks_ok && !sticks.active)
					sticks.show_all();
			}
        }
    }

    private void check_mission(string missionlog) {
        bool done = false;
        string mfn = null;

        var dis = FileStream.open(missionlog,"r");
        if (dis != null) {
            var parser = new Json.Parser ();
            string line = null;
            while (!done && (line = dis.read_line ()) != null) {
                try {
                    parser.load_from_data (line);
                    var obj = parser.get_root ().get_object ();
                    var typ = obj.get_string_member("type");
                    switch(typ) {
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
        if(mfn != null) {
            hard_display_reset(true);
            load_file(mfn, false);
        }
        else {
            hard_display_reset(false);
        }
    }

    private void spawn_otx_task(string fn, bool delay, int idx, int typ=0, uint dura=0) {
        var dstr = "udp://localhost:%d".printf(playfd[1]);
        string [] args={};
        if ((replayer & Player.RAW) == Player.RAW) {
            args += "mwp-log-replay";
            args += "-d";
            args += dstr;
            if (idx > 10) {
                double dly = (double)idx/1000.0;
                args += "-delay";
                args += "%.3f".printf(dly);
            }
        } else {
            if (x_fl2ltm) {
                args += "fl2ltm";
                if (last_file != null) {
                    args += "-mission";
                    args += (MwpMisc.is_cygwin()==false) ? last_file : MwpMisc.get_native_path(last_file);
                }
                args += "-device";
            } else {
                args += "otxlog";
                args += "-d";
            }
            args += dstr;
            args += "--index";
            args += idx.to_string();
            if(delay == false)
                args += "--fast";

            args += "--type";
            args += typ.to_string();
            if (dura > 600) {
                uint intvl  =  100 * dura / 600;
                args += "-interval";
                args += intvl.to_string();
            } else if (x_fl2ltm) {
                args += "-interval";
                args += "100";
            }
        }
        args += (MwpMisc.is_cygwin()==false) ? fn : MwpMisc.get_native_path(fn);
        args += null;

		string sargs = string.joinv(" ",args);

        try {
            var spf = SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD;

            if ((debug_flags & DEBUG_FLAGS.OTXSTDERR) == 0) {
                spf |= SpawnFlags.STDERR_TO_DEV_NULL;
            }
            Process.spawn_async_with_pipes (null, args, null, spf,
											null,
                                            out child_pid,
                                            null, null, null);
        } catch (SpawnError e) {
            MWPLog.message("spawnerror: %s %s \n", sargs, e.message);
        }
		MWPLog.message("%s # pid=%u\n", sargs, child_pid);

		ChildWatch.add (child_pid, (pid, status) => {
				Process.close_pid (pid);
				cleanup_replay();
			});
    }

    private void spawn_bbox_task(string fn, int index, int btype,
                                 bool delay, uint8 force_gps, uint duration) {
        if(x_fl2ltm) {
            replayer |= Player.OTX;
            spawn_otx_task(fn, delay, index, btype, duration);
        } else {
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

            if(duration > 600) {
                uint intvl  =  100000 * duration / 600;
                args += "-I";
                args += intvl.to_string();
            }
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
                                                    for(var i = 3; i < 512; i++) {
                                                        if(i != playfd[1])
                                                            Posix.close(i);
                                                    }
                                                }),
                                                out child_pid,
                                                null, null, null);
                ChildWatch.add (child_pid, (pid, status) => {
                        Process.close_pid (pid);
                        cleanup_replay();
                    });
            } catch (SpawnError e) {
                MWPLog.message("spawnerror: %s\n", e.message);
            }
        }
    }

    private void replay_bbox (bool delay, string? fn = null) {
		bbl_delay = delay;
		if((replayer & Player.BBOX) == Player.BBOX) {
            Posix.kill(child_pid, MwpSignals.Signal.TERM);
        } else if ((replayer & Player.OTX) == Player.OTX) {
                /// tidy this up
        } else {
			bb_runner.run(fn);
		}
	}

    private void stop_replayer() {
        if(replay_paused)
            handle_replay_pause();

        if((replayer & (Player.BBOX|Player.OTX)) != 0)
            Posix.kill(child_pid, MwpSignals.Signal.TERM);

        if((replayer & Player.MWP) == Player.MWP && thr != null)
            robj.stop();
        replay_paused = false;
    }

	private void request_common_setting(string s) {
		uint8 msg[128];
		var k = 0;
		for(; k < s.length; k++) {
			msg[k] = s.data[k];
		}
		msg[k++] = 0;
		MWPLog.message("Request setting %s\n", s);
		queue_cmd(MSP.Cmds.COMMON_SETTING, msg, k);
	}

	private void start_download() {
		serstate = SERSTATE.NORMAL;
		mq.clear();
		start_wp_timer(30*1000);
		request_wp(1);
	}

    private void download_mission() {
        check_mission_clean(do_download_mission);
    }

    private void do_download_mission() {
        wpmgr.wp_flag = 0;
		wpmgr.wps = {};
		wpmgr.npts = last_wp_pts;
		if (last_wp_pts > 0 || !inav) {
			imdx = 0;
			if  (vi.fc_vers >= FCVERS.hasWP_V4) {
				wpmgr.wp_flag = WPDL.KICK_DL;
				request_common_setting("nav_wp_multi_mission_index");
			} else {
				start_download();
			}
		} else {
			mwp_warning_box("No WPs in FC to download\nMaybe 'Restore' is needed?",
							Gtk.MessageType.WARNING, 10);
		}
    }

    public static void xchild() {
        JsonMapDef.killall();
        if(Logger.is_logging)
            Logger.stop();
    }

    OptionEntry ? find_option(string s) {
        foreach(var o in options) {
            if (s[1] == '-') {
                if(s[2:s.length] == o.long_name) {
                    return o;
                }
            } else if (s[1] == o.short_name) {
                return o;
            }
        }
        return null;
    }

    private  VariantDict  check_env_args(string?s) {
        VariantDict v = new VariantDict();
        if(s != null) {
			var sb = new StringBuilder(MWP.user_args);
			sb.append(s);
			MWP.user_args = sb.str;

            string []m;
            try {
                Shell.parse_argv(s, out m);
                for(var i = 0; i < m.length; i++) {
                    string extra=null;
					string optname = null;
                    int iarg;
					var mparts = m[i].split("=");
					optname = mparts[0];
					if (mparts.length > 1) {
						extra = mparts[1];
					}

                    var o = find_option(optname);
                    if (o != null) {
                        if (o.arg !=  OptionArg.NONE && extra == null) {
                            extra = m[++i];
						}
                        switch(o.arg) {
						case OptionArg.NONE:
							if (o.long_name != null)
								v.insert(o.long_name, "b", true);
                                if (o.short_name != 0)
                                    v.insert(o.short_name.to_string(), "b", true);
                                break;
						case OptionArg.STRING:
							if (o.long_name != null)
								v.insert(o.long_name, "s", extra);
							if (o.short_name != 0)
								v.insert(o.short_name.to_string(), "s", extra);
							break;
						case OptionArg.INT:
							iarg = int.parse(extra);
							if (o.long_name != null)
								v.insert(o.long_name, "i", iarg);
							if (o.short_name != 0)
								v.insert(o.short_name.to_string(), "i", iarg);
							break;
						case OptionArg.STRING_ARRAY:
							VariantBuilder builder = new VariantBuilder (new VariantType ("as") );
							if(v.contains(o.long_name)) {
								var ox = v.lookup_value(o.long_name, VariantType.STRING_ARRAY);
								var extras = ox.dup_strv();
								foreach (var se in extras) {
									builder.add ("s",se);
								}
							}
							builder.add ("s", extra);
							v.insert(o.long_name, "as", builder);
							break;

						default:
								MWPLog.message("Error ARG PARSE %s %s\n", o.long_name, o.arg.to_string());
                                break;
                        }
                    }
                }
            } catch (Error e) {
				MWPLog.message("*** Internal Dict Error %s\n", e.message);
			}
        }
        return v;
    }

    private static string? check_virtual(string? os) {
        string hyper = null;
        string cmd = null;
        switch (os) {
            case "Linux":
                cmd = "systemd-detect-virt";
                break;
            case "FreeBSD":
                cmd = "sysctl kern.vm_guest";
                break;
        }

        if(cmd != null) {
            try {
                string strout;
                int status;
                Process.spawn_command_line_sync (cmd, out strout,
                                                 null, out status);
                if(Process.if_exited(status)) {
                    strout = strout.chomp();
                    if(strout.length > 0) {
                        if(os == "Linux")
                            hyper = strout;
                        else {
                            var index = strout.index_of("kern.vm_guest: ");
                            if(index != -1)
                                hyper = strout.substring(index+"kern.vm_guest: ".length);
                        }
                    }
                }
            } catch (SpawnError e) {}

            if(hyper != null)
                return hyper;
        }

        try {
            string[] spawn_args = {"dmesg"};
            int p_stdout;
            Pid child_pid;

            Process.spawn_async_with_pipes (null,
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
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

            try {
                for(;;) {
                    eos = chan.read_line (out line, out length, null);
                    if(eos == IOStatus.EOF)
                        break;
                    if(line == null || length == 0)
                        continue;
                    line = line.chomp();
                    var index = line.index_of("Hypervisor");
                    if(index != -1) {
                        hyper = line.substring(index);
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

    private static string? read_env_args() {
		/***
		var u = Posix.utsname();
		if (!u.release.contains("microsoft-standard-WSL")) {
			if(Environment.get_variable("GDK_BACKEND") == null)
				Environment.set_variable("GDK_BACKEND", "x11", true);
		}
		****/
		var s1 = read_cmd_opts();
        var s2 = Environment.get_variable("MWP_ARGS");
        var sb = new StringBuilder();
        if(s1.length > 0)
           sb.append(s1);
        if(s2 != null)
            sb.append(s2);

		if(sb.len > 0)
            return sb.str;
		return null;
    }

    private static string read_cmd_opts() {
        var sb = new StringBuilder ();
        var fn = MWPUtils.find_conf_file("cmdopts");
        if(fn != null) {
            var file = File.new_for_path(fn);
            try {
                var dis = new DataInputStream(file.read());
                string line;
                while ((line = dis.read_line (null)) != null) {
                    if(line.strip().length > 0) {
						if(line.has_prefix("#") || line.has_prefix(";")) {
							continue;
						} else if (line.has_prefix("-")) {
							sb.append(line);
							sb.append_c(' ');
						} else if (line.contains("=")) {
							var parts = line.split("=");
							if (parts.length == 2) {
								var ename = parts[0].strip();
								var evar = parts[1].strip();
								Environment.set_variable(ename, evar, true);
							}
						}
					}
				}
			} catch (Error e) {
                error ("%s", e.message);
            }
        }
        return sb.str;
    }

	public static int main (string[] args) {
		MWPUtils.set_app_name("mwp");
		Environment.set_prgname(MWP.MWPID);
		MwpLibC.atexit(MWP.xchild);
        var s = MWP.read_env_args();

		StringBuilder sb = new StringBuilder();
		foreach(var a in args) {
            if (a == "--version" || a == "-v") {
                stdout.printf("%s\n", MwpVers.get_id());
                return 0;
            }
			sb.append(a);
			sb.append_c(' ');
		}
		if (GtkClutter.init (ref args) != InitError.SUCCESS) {
			stderr.printf("Fatal: can't GtkClutter.init\n");
            return 17;
		}
        Gst.init (ref args);
		MWP.user_args = sb.str;
        var app = new MWP(s);
		return app.run (args);
    }
}
