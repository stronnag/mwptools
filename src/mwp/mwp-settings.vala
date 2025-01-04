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

public class MWPSettings : GLib.Object {
    public Settings settings {get; set;}
    private const string sname = "org.stronnag.mwp";
	//    private SettingsSchema schema;
    public double latitude {get; set; default=0.0;}
    public double longitude {get; set; default=0.0;}
    public uint loiter {get; set; default=30;}
    public int altitude {get; set; default=20;}
    public double nav_speed {get; set; default=2.5;}
    public uint zoom {get; set; default=12;}
    public string? defmap {get; set; default="";}
    public string[]? devices {get; set; default={};}
    public bool dump_unknown {get; set; default=false;}
    public bool beep {get; set; default=true;}
    public bool dms {get; set; default=false;}
    public string? map_sources {get; set; default="";}
    public uint  speakint {get; set; default=0;}
    public uint  buadrate {get; set; default=57600;}
    public string evoice {get; set; default="";}
    public string svoice {get; set; default="";}
    public string fvoice {get; set; default="";}
    public bool audioarmed {get; set; default=false;}
    public bool logarmed {get; set; default=false;}
    public bool autofollow {get; set; default=true;}
    public uint  baudrate {get; set; default=57600;}
    public string atstart {get; set;}
    public string atexit {get; set;}
    public string? vlevels {get; set;}
    public uint polltimeout {get; set; default=900;}
    public uint p_distance {get; set; default=0;}
    public uint p_speed {get; set; default=0;}
    public uint gpsintvl {get; set; default = 2000;}
    public string uilang {get; set; default="";}
    public string led {get; set; default="";}
    public string rcolstr {get; set; default="";}
    public bool rth_autoland {get; set; default=false;}
    public string missionpath {get; set; default="";}
    public string logpath {get; set; default="";}
    public string logsavepath {get; set; default="";}
    public double max_home_delta {get; set; default=2.5;}
    public bool ignore_nm {get; set; default=false;}
    public string speech_api {get; set; default="";}
    public uint stats_timeout {get; set; default=30;}
    public bool auto_restore_mission {get; set; default=false;}
    public int forward {get; set; default=0;}
    public string wp_text {get; set; default="Sans 72/#ff000060";}
    public string wp_spotlight {get; set; default="#ffffff60";}
    public uint flash_warn { get; set; default=0; }
    public bool horizontal_dbox {get; set; default=false;}
    public uint osd_mode {get; set; default=3;}
    public double wp_dist_fontsize {get; set; default=56;}
    public bool adjust_tz {get; set; default=true;}
    public string blackbox_decode {get; set; default="blackbox_decode";}
    public string geouser {get; set; default="";}
    public string zone_detect {get; set; default="";}
    public string mag_sanity {get; set; default="";}
    public bool say_bearing {get; set; default=true;}
    public bool pos_is_centre {get; set; default=true;}
    public double deltaspeed {get; set; default=0.0;}
    public int smartport_fuel  {get; set; default = 0;}
    public int speak_amps {get; set; default=0;}
    public bool arming_speak {get; set; default=false;}
    public bool manage_power {get; set; default=false;}
    public uint max_radar { get; set; default=4; }
    public string kmlpath {get; set; default="";}
    public bool ucmissiontags {get; set; default=false;}
    public bool missionmetatag {get; set; default=false;}
	public bool autoload_safehomes {get; set; default=false;}
    public double maxclimb {get; set; default=0;}
    public double maxdive {get; set; default=0;}
    public uint max_wps { get; set; default=60; }
    public int ga_speed {get; set; default=0;}
    public int ga_alt {get; set; default=0;}
    public int ga_range {get; set; default=0;}
    public uint max_radar_altitude {get; set; default=0;}
    public uint radar_alert_altitude {get; set; default=0;}
    public uint radar_alert_range {get; set; default=0;}
    public string gpsdhost {get; set; default="localhost";}
    public int misciconsize {get; set; default=32;}
    public int show_sticks {get; set; default=2;}
    public uint view_mode {get; set; default=0;}
    public int msp2_adsb {get; set; default=0;}
    public int pane_type {get; set; default=0;}
	public int los_margin {get; set; default=0;}
	public bool bluez_disco {get; set; default=true;}
	public bool autoload_geozones {get; set; default=false;}
	public int min_dem_zoom {get; set; default=9;}
	public string mapbox_apikey {get; set; default="";}
	public double symbol_scale {get; set; default=1.0;}
	public double touch_scale {get; set; default=1.0;}
	public int ident_limit  {get; set; default=60;}
	public double touch_factor {get; set; default=0.0;}
	public int p_pane_width {get; set; default=0;}
	public bool armed_msp_placebo {get; set; default=false;}

	construct {
#if DARWIN
		string uc =  Environment.get_user_config_dir();
		string kfile = GLib.Path.build_filename(uc,"mwp");
		DirUtils.create_with_parents(kfile, 0755);
		kfile = GLib.Path.build_filename(kfile , "mwp.ini");
		if(!FileUtils.test(kfile, FileTest.EXISTS|FileTest.IS_REGULAR)) {
			bool ok = false;
			var ud =  Environment.get_user_data_dir();
			var sds =  Environment.get_system_data_dirs();
			var fn =  GLib.Path.build_filename(ud, "mwp", "mwp.ini");
			if (!FileUtils.test(fn, FileTest.EXISTS|FileTest.IS_REGULAR)) {
				foreach (var sd in sds) {
					fn =  GLib.Path.build_filename(sd, "mwp", "mwp.ini");
					if (FileUtils.test(fn, FileTest.EXISTS|FileTest.IS_REGULAR)) {
						ok = true;
						break;
					}
				}
			} else {
				ok = true;
			}
			if(ok) {
				string defset;
				try {
					if(FileUtils.get_contents(fn, out defset)) {
						FileUtils.set_contents(kfile, defset);
					}
				} catch (Error e) {
					MWPLog.message("Copy settings: %s\n", e.message);
				}
			}
		}
		MWPLog.message("Using settings keyfile %s\n", kfile);
		SettingsBackend kbe = SettingsBackend.keyfile_settings_backend_new(kfile, "/org/stronnag/mwp/","mwp");
		settings = new Settings.with_backend(sname, kbe);
#else
		MWPLog.message("Using settings schema %s\n", sname);
		settings =  new Settings (sname);
#endif
		settings.bind("adjust-tz", this, "adjust-tz", SettingsBindFlags.DEFAULT);
		settings.bind("armed-msp-placebo", this, "armed-msp-placebo", SettingsBindFlags.DEFAULT);
		settings.bind("arming-speak", this, "arming-speak", SettingsBindFlags.DEFAULT);
		settings.bind("atexit", this, "atexit", SettingsBindFlags.GET);
		settings.bind("atstart", this, "atstart", SettingsBindFlags.GET);
		settings.bind("audio-on-arm", this, "audioarmed", SettingsBindFlags.DEFAULT);
		settings.bind("auto-follow", this, "autofollow", SettingsBindFlags.DEFAULT);
		settings.bind("auto-restore-mission", this, "auto-restore-mission", SettingsBindFlags.DEFAULT);
		settings.bind("autoload-geozones", this, "autoload-geozones", SettingsBindFlags.DEFAULT);
		settings.bind("baudrate", this, "baudrate", SettingsBindFlags.DEFAULT);
		settings.bind("beep", this, "beep", SettingsBindFlags.DEFAULT);
		settings.bind("blackbox-decode", this, "blackbox-decode", SettingsBindFlags.DEFAULT);
		settings.bind("bluez-disco", this, "bluez-disco", SettingsBindFlags.DEFAULT);
		settings.bind("default-altitude", this, "altitude", SettingsBindFlags.DEFAULT);
		settings.bind("default-latitude", this, "latitude", SettingsBindFlags.DEFAULT);
		settings.bind("default-loiter", this, "loiter", SettingsBindFlags.DEFAULT);
		settings.bind("default-longitude", this, "longitude", SettingsBindFlags.DEFAULT);
		settings.bind("default-map", this, "defmap", SettingsBindFlags.DEFAULT);
		settings.bind("default-nav-speed", this, "nav-speed", SettingsBindFlags.DEFAULT);
		settings.bind("default-zoom", this, "zoom", SettingsBindFlags.DEFAULT);
		settings.bind("delta-minspeed", this, "deltaspeed", SettingsBindFlags.DEFAULT);
		settings.bind("display-distance", this, "p-distance", SettingsBindFlags.DEFAULT);
		settings.bind("display-dms", this, "dms", SettingsBindFlags.DEFAULT);
		settings.bind("display-speed", this, "p-speed", SettingsBindFlags.DEFAULT);
		settings.bind("dump-unknown", this, "dump-unknown", SettingsBindFlags.DEFAULT);
		settings.bind("espeak-voice", this, "evoice", SettingsBindFlags.DEFAULT);
		settings.bind("flash-warn", this, "flash-warn", SettingsBindFlags.DEFAULT);
		settings.bind("flite-voice-file", this, "fvoice", SettingsBindFlags.DEFAULT);
		settings.bind("ga-alt", this, "ga-alt", SettingsBindFlags.DEFAULT);
		settings.bind("ga-range", this, "ga-range", SettingsBindFlags.DEFAULT);
		settings.bind("ga-speed", this, "ga-speed", SettingsBindFlags.DEFAULT);
		settings.bind("geouser", this, "geouser", SettingsBindFlags.DEFAULT);
		settings.bind("gpsd-host", this, "gpsdhost", SettingsBindFlags.DEFAULT);
		settings.bind("gpsintvl", this, "gpsintvl", SettingsBindFlags.DEFAULT);
		settings.bind("ident-limit", this, "ident_limit", SettingsBindFlags.DEFAULT);
		settings.bind("ignore-nm", this, "ignore-nm", SettingsBindFlags.DEFAULT);
		settings.bind("kml-path", this, "kmlpath", SettingsBindFlags.DEFAULT);
		settings.bind("led", this, "led", SettingsBindFlags.DEFAULT);
		settings.bind("autoload-safehomes", this, "autoload-safehomes", SettingsBindFlags.DEFAULT);
		settings.bind("log-on-arm", this, "logarmed", SettingsBindFlags.DEFAULT);
		settings.bind("log-path", this, "logpath", SettingsBindFlags.DEFAULT);
		settings.bind("log-save-path", this, "logsavepath", SettingsBindFlags.DEFAULT);
		settings.bind("los-margin", this, "los-margin", SettingsBindFlags.DEFAULT);
		settings.bind("mapbox-apikey", this, "mapbox-apikey", SettingsBindFlags.DEFAULT);
		settings.bind("mag-sanity", this, "mag-sanity", SettingsBindFlags.DEFAULT);
		settings.bind("manage-power", this, "manage-power", SettingsBindFlags.DEFAULT);
		settings.bind("map-sources", this, "map-sources", SettingsBindFlags.DEFAULT);
		settings.bind("max-home-delta", this, "max-home-delta", SettingsBindFlags.DEFAULT);
		settings.bind("max-radar-slots", this, "max-radar", SettingsBindFlags.DEFAULT);
		settings.bind("radar-list-max-altitude", this, "max-radar-altitude", SettingsBindFlags.DEFAULT);
		settings.bind("max-wps", this, "max-wps", SettingsBindFlags.DEFAULT);
		settings.bind("max-climb-angle", this, "maxclimb", SettingsBindFlags.DEFAULT);
		settings.bind("max-dive-angle", this, "maxdive", SettingsBindFlags.DEFAULT);
		settings.bind("min-dem-zoom", this, "min-dem-zoom", SettingsBindFlags.DEFAULT);
		settings.bind("misc-icon-size", this, "misciconsize", SettingsBindFlags.DEFAULT);
		settings.bind("mission-path", this, "missionpath", SettingsBindFlags.DEFAULT);
		settings.bind("mission-meta-tag", this, "missionmetatag", SettingsBindFlags.DEFAULT);
		settings.bind("osd-mode", this, "osd-mode", SettingsBindFlags.DEFAULT);
		settings.bind("p-pane-width", this, "p-pane-width", SettingsBindFlags.DEFAULT);
		settings.bind("poll-timeout", this, "polltimeout", SettingsBindFlags.DEFAULT);
		settings.bind("pos-is-centre", this, "pos-is-centre", SettingsBindFlags.DEFAULT);
		settings.bind("radar-list-max-altitude", this, "radar-alert-altitude", SettingsBindFlags.DEFAULT);
		settings.bind("radar-alert-range", this, "radar-alert-range", SettingsBindFlags.DEFAULT);
		settings.bind("rings-colour", this, "rcolstr", SettingsBindFlags.DEFAULT);
		settings.bind("rth-autoland", this, "rth-autoland", SettingsBindFlags.DEFAULT);
		settings.bind("say-bearing", this, "say-bearing", SettingsBindFlags.DEFAULT);
		settings.bind("speak-interval", this, "speakint", SettingsBindFlags.DEFAULT);
		settings.bind("speech-api", this, "speech-api", SettingsBindFlags.DEFAULT);
		settings.bind("speechd-voice", this, "svoice", SettingsBindFlags.DEFAULT);
		settings.bind("stats-timeout", this, "stats-timeout", SettingsBindFlags.DEFAULT);
		settings.bind("symbol-scale", this, "symbol-scale", SettingsBindFlags.DEFAULT);
		settings.bind("touch-scale", this, "touch-scale", SettingsBindFlags.DEFAULT);
		settings.bind("touch-factor", this, "touch-factor", SettingsBindFlags.DEFAULT);
		settings.bind("uc-mission-tags", this, "ucmissiontags", SettingsBindFlags.DEFAULT);
		settings.bind("uilang", this, "uilang", SettingsBindFlags.DEFAULT);
		settings.bind("vlevels", this, "vlevels", SettingsBindFlags.DEFAULT);
		settings.bind("wp-dist-size", this, "wp-dist-fontsize", SettingsBindFlags.DEFAULT);
		settings.bind("wp-spotlight", this, "wp-spotlight", SettingsBindFlags.DEFAULT);
		settings.bind("wp-text-style", this, "wp-text", SettingsBindFlags.DEFAULT);
		settings.bind("zone-detect", this, "zone-detect", SettingsBindFlags.DEFAULT);

		settings.bind("p-width", Mwp.window, "default-width", SettingsBindFlags.DEFAULT);
		settings.bind("p-height", Mwp.window, "default-height", SettingsBindFlags.DEFAULT);
		settings.bind("p-is-maximised", Mwp.window, "maximized", SettingsBindFlags.DEFAULT);
		settings.bind("p-is-fullscreen", Mwp.window, "fullscreened", SettingsBindFlags.DEFAULT);
	}

    public MWPSettings() {
		forward = settings.get_enum("forward");
		view_mode = settings.get_enum("view-mode");
		speak_amps = settings.get_enum("speak-amps");
		show_sticks = settings.get_enum("show-sticks");
		msp2_adsb = settings.get_enum("msp2-adsb");
		pane_type = settings.get_enum("sidebar-type");
		smartport_fuel = settings.get_enum("smartport-fuel-unit");
		devices = settings.get_strv ("device-names");
		if (devices == null) {
			devices = {};
		}
		if(speakint > 0 && speakint < 15) {
			speakint = 15;
		}
		if(p_distance > 2) {
			p_distance = 0;
		}
		if(p_speed > 3) {
			p_distance = 0;
		}
		if(missionpath == null || missionpath == "") {
			missionpath = UserDirs.get_default();
		}
		if(kmlpath == null || kmlpath == "") {
			kmlpath = UserDirs.get_default();
		}
		if(logpath == null || logpath == "") {
			logpath = UserDirs.get_default();
		}
		if(logsavepath == null || logsavepath == "") {
			logsavepath = UserDirs.get_default();
		}
	}
}
