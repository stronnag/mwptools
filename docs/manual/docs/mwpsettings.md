### List of mwp settings

| Name | Summary | Description | Default |
| ---- | ------- | ----------- | ------ |
| adjust-tz | Adjust FC's TZ (and DST) | Option for whether mwp should adjust FC's TZ (and DST) based on the local clock | true |
| alt-prefer-agl | Altitude / AGL Display | If true, where valid DEM is available for home and vehicle locations, AGL (Above Ground Level) will be shown in place of home relative altitude. | false |
| armed-msp-placebo | Antidote to armed menus placebo | Whether to suppress desensitising of MSP action items when armed. | false |
| arming-speak | Speak arming states | Whether to reporting arming state by audio | false |
| assist-key | Ublox Assist now key | Ublox Assist now key. Setting blank ('') disables, unless the API key is in the `libsecret` credential store. | "" |
| atexit | Something that is executed at exit | e.g. `gsettings set org.gnome.settings-daemon.plugins.power idle-dim true`. See also `manage-power` (and consider setting `manage-power` to `true` instead). | "" |
| atstart | Something that is executed at startup | e.g. `gsettings set org.gnome.settings-daemon.plugins.power idle-dim false`. See also `manage-power` (and consider setting to true). | "" |
| audio-on-arm | Start audio on arm | Option to start audio on arm (and stop on disarm) | true |
| auto-follow | Set auto-follow | Option to set auto-follow on start (track vehicle) | true |
| auto-restore-mission | Whether to automatically import a mission in FC memory to MWP | If the FC holds a valid mission in memory, and there is no mission loaded into MWP, this setting controls whether MWP automatically downloads the mission. | false |
| autoload-geozones | Autoload geozones from FC | Autoload geozones from FC on FC connect, remove from display on FC disconnect | false |
| autoload-safehomes | Load safehomes on connect | If true, then safehomes will be loaded from the FC on connection. | false |
| baudrate | Baud rate | Serial baud rate | 115200 |
| beep | Beep for alerts | Option to emit an alert sound for alerts. | true |
| blackbox-decode | Name of the blackbox_decode application | Name of the blackbox_decode application (in case there are separate for iNav and betaflight) | "blackbox_decode" |
| bluez-disco | Use Bluetooth discovery | (Linux only) Only discovered Bluetooth serial devices with non-zero RSSI will be offered | true |
| default-altitude | Default altitude | Default Altitude for mission (m) | 20 |
| default-latitude | Default Latitude | Default Latitude when no GPS | 50.909528 |
| default-loiter | Default Loiter time | Default Loiter time | 30 |
| default-longitude | Default Longitude | Default Longitude when no GPS | -1.532936 |
| default-map | Default Map | Default map *key* | "" |
| default-nav-speed | Default Nav speed | Default Nav speed (m/s). For calculating durations only. | 7.0 |
| default-video-uri | Default video URI | Default entry in the video player URI chooser | "" |
| default-zoom | Default Map zoom | Default map zoom | 15 |
| delta-minspeed | Minimum speed for elapsed distance updates | Minimum speed for elapsed distance updates (m/s). Default is zero, which means the elapsed distance is always updated; larger values will take out hover / jitter movements. | 0.0 |
| device-names | Device names | A list of device names to be added to those that can be auto-discovered | [] |
| display-distance | Distance units | 0=metres, 1=feet, 2=yards | 0 |
| display-dms | Position display | Show positions as dd:mm:ss rather than decimal degrees | false |
| display-speed | Speed units | 0=metres/sec, 1=kilometres/hour, 2=miles/hour, 3=knots | 0 |
| dump-unknown | dump unknown | dump unknown message payload (debug aid) | false |
| espeak-voice | Default espeak voice | Default espeak voice (see espeak documentation) | "en" |
| flash-warn | Flash storage warning | If a dataflash is configured for black box, and this key is non-zero, a warning in generated if the data flash is greater than "flash-warn" percent full. | 0 |
| flite-voice-file | Default flite voice file | Default flite voice file (full path, *.flitevox), see flite documentation) | "" |
| forward | Types of message to forward | Types of message to forward (none, LTM, minLTM, minMAV, all, MSP1, MSP2, MAV1, MAV2) | "minLTM" |
| ga-alt | Units for GA (ADSB) Altiude | 0=m, 1=ft, 2=FL | 0 |
| ga-range | Units for GA (ADSB) Range | 0=m, 1=km, 2=miles, 3=nautical miles | 0 |
| ga-speed | Units for GA (ADSB) Speed | 0=m/s, 1=kph, 2=mph, 3=knots | 0 |
| geouser | User account on geonames.org | A user account to query geonames.org for blackbox log timezone info. A default account of 'mwptools' is provided; however users are requested to create their own account. | "mwptools" |
| gpsd-host | Gpsd provider | Provider for GCS icon location via gpsd. Default is "localhost", can be set to other host name or IP address. Setting blank ('') disables. | "localhost" |
| gpsintvl | Gps sanity time (m/s) | Gps sanity time (m/s), check for current fix | 2000 |
| ident-limit | MSP_IDENT limit for MSP recognition | Timeout value in seconds for a MSP FC to reply to a MSP_INDENT probe. Effectively a timeout counter in seconds. Set to a negative value to disable. | 60 |
| ignore-nm | Ignore Network Manager | Linux / FreeBSD : Set to true to always ignore NM status (may slow down startup) | false |
| kml-path | Directory for KML overlays | Directory for KML overlays, default / not set = current directory | "" |
| log-on-arm | Start logging on arm | Option to start logging on arm (and stop on disarm) | false |
| log-path | Directory for replay log files | Directory for log files (for replay), default = current directory | "" |
| log-save-path | Directory for storing log files | Directory for log files (for save), default / not set = current directory | "" |
| los-margin | Margin(m) for LOS Analysis | Margin(m) for LOS Analysis | 0 |
| mag-sanity | Enable mag sanity checking | Mwp offers a primitive mag sanity checker that compares compass heading with GPS course over the ground using LTM (only). There are various hard-coded constraints (speed > 3m/s, certain flight modes) and two configurable parameters that should be set here in order to enable this check. The parameters are angular difference (⁰) and duration (s). The author finds a settings of 45,3 (i.e. 45⁰ over 3 seconds) works OK, detecting real instances (a momentarily breaking cable) and not reporting false positives. | "" |
| manage-power | Manage power and screen | Whether to manage idle and screen saver | false |
| map-sources | Additional Map sources | JSON file defining additional map sources | "" |
| mapbox-apikey | Mapbox API Key | Mapbox API key, enables Mapbox as a map Provider. Setting blank ('') disables, unless the API key is in the `libsecret` credential store. | "" |
| mavlink-sysid | Sysid for synthesised MAVLink | System ID in the range 2-255 (see <a href="https://ardupilot.org/dev/docs/mavlink-basics.html#message-format">MAVlink documentation</a> and particularly the GCS guidance, 2nd paragraph <i>ibid</i>) | 106 |
| max-climb-angle | Maximum climb angle highlight for terrain analysis | If non-zero, any climb angles exceeding the specified value will be highlighted in Terrain Analysis - Climb / Dive report. Note that the absolute value is taken as a positive (climb) angle | 0.0 |
| max-dive-angle | Maximum dive angle highlight for terrain analysis | If non-zero, any dive angles exceeding the specified value will be highlighted in Terrain Analysis Climb / Dive report. Note that the absolute value is taken as a negative (dive) angle | 0.0 |
| max-home-delta | Home position delta (m) | Maximum variation of home position without verbal alert | 2.5 |
| max-radar-slots | Maximum number of INAV Radar vehicles | Maximum number of vehicles reported by INAV Radar | 4 |
| max-wps | Maximum number of WP supported | Maximum number of WP supported (should match most capable FC firmware) | 120 |
| min-dem-zoom | Minimum zoom for DEM loading | DEMs will not be fetched if zoom is below this value | 9 |
| mission-icon-alpha | Alpha for mission icons | Alpha (opacity) for mission icons in the range 0 - 255. | 160 |
| mission-meta-tag | Use meta vice mwp in mission file | If true, the legacy 'mwp' tag for optional data in mission files is named 'meta' | false |
| mission-path | Directory for mission files | Directory for mission files, default / not set = current directory | "" |
| msp2-adsb | MSP2_ADSB_VEHICLE_LIST usage | Options for requesting MSP2_ADSB_VEHICLE_LIST. "off": never request, "on:" always request, "auto:" heuristic based on serial settings / bandwidth | "off" |
| msprc-cycletime | MSP_SET_RAW_RC cycle time (microseconds) | Cycle time (ms) for MSP_SET_RAW_RC messages (if enabled). INAV requires a minimum of 5Hz refresh (200ms). A lower cycle time will improve RC response but reduce the MSP telemetry refresh rate | 150 |
| msprc-enabled | MSP_SET_RAW_RC enablement | Whether MSP_SET_RAW_RC message transmission is enabled. Requires a mapping file | false |
| msprc-full-duplex | MSP_SET_RAW_RC full duplex transmission | Use full duplex transmission for MSP_SET_RAW_RC messages. This will better ensure that the cycle-time requirement is met. <b>If the device does not support full duplex, enabling this will result in major telemetry failure</b>. | false |
| msprc-settings | Handset Mapping file | Mapping file defining the mapping between handset input devices to RC channels for MSP_SET_RAW_RC messages | "" |
| mwxml-version | MultiMission XML version | Version value in MW XML mission files. Legacy MW requires `2.3 pre8`. Note that INAV mission files may not be NOT compatible with legacy MW (and vice versa). If not set, the mwp version number is used. | "" |
| no-poller-pause | Don't pause the MSP poller for bulk transfers | Traditionally, mwp pauses the MSP poller for bulk transfers (WP, Geozone, Safehome). This option allows polling to continue, interleaved with the bulk transfer. | false |
| osd-mode | Data items overlaid on the map OSD | 0 = none, 1 = current WP/Max WP, 2 = next WP distance and course. This is a mask, so 3 means both OSD items. | 3 |
| p-height | Internal setting |  | 720 |
| p-is-fullscreen | Internal setting |  | false |
| p-is-maximised | Internal setting |  | true |
| p-pane-vertical | Internal setting | Please do not change this unless you appreciate the consequences | true |
| p-pane-width | Internal setting | Please do not change this unless you appreciate the consequences | 0 |
| p-width | Internal setting |  | 1280 |
| poll-timeout | Poll messages timeout (ms) | Timeout in milliseconds for telemetry poll messages. Note that timer loop has a resolution of 10ms. | 900 |
| pos-is-centre | Determines position label content | Whether the position label is the map centre or the pointer location | false |
| radar-alert-altitude | Altitude below which ADS-B alerts may be generated | Target altitude (metres) below which ADS-B proximity alerts may be generated. Requires that 'radar-alert-range' is also set (non-zero). Setting to 0 disables. Note that ADS-B altitudes are AMSL (or geoid). | 0 |
| radar-alert-min-speed | Speed above which ADS-B alerts may be generated | Target speed (metres/sec) above which ADS-B proximity alerts may be generated. Requires that 'radar-alert-altitude' and "radar-alert-range" are also set. | 10 |
| radar-alert-range | Range below which ADS-B alerts may be generated | Target range (metres) below which ADS-B proximity alerts may be generated. Requires that 'radar-alert-altitude' is also set (non-zero). Setting to 0 disables. | 0 |
| radar-list-max-altitude | Maximum altitude for targets to show in the radar list view | Maximum altitude (metres) to include targets in the radar list view. Targets higher than this value will show only in the map view. This is mainly for ADS-B receivers where there is no need for high altitude targets to be shown. Setting to 0 disables. Note that ADS-B altitudes are AMSL (or geoid). | 0 |
| rings-colour | Range rings colour | Range rings colour as well know string or #RRGGBBAA | "#ffffff20" |
| rth-autoland | Set land on RTH waypoints | Automatically assert land on RTH waypoints | false |
| say-bearing | Whether audio report includes bearing | Whether audio report includes bearing | true |
| show-sticks | Whether to show stick poisitons in log replay | If "yes", stick position is shown bottom right during log replay, if "no" , never shown. If "icon", then it shown iconified (bottom right) | "icon" |
| sidebar-type | Internal setting | Options for the sidebar type. Unless you know better, leave at auto | "auto" |
| smartport-fuel-unit | User selected fuel type | Units label for smartport fuel (none, %, mAh, mWh) | "none" |
| speak-amps | When to speak amps/hr used | Enumeration of none, live-n, all-n n=1,2,4 : n = how often spoken (modulus basically) | "none" |
| speak-interval | Interval between voice prompts | Interval between voice prompts, 0 disables | 15 |
| speech-api | API for speech synthesis | On of espeak, speechd, flite. Only change this if you know you have the required development files at build time | "espeak" |
| speechd-voice | Default speechd voice | Default speechd voice (see speechd documentation) | "male1" |
| sqlite-log-path | Directory to save SQLite log files | Directory to save SQLite log files, if not set, SQLite log files ("Interactive FlightLog replay" are not persisted. | "" |
| stats-timeout | Timeout for flight statistics display (s) | Timeout before the flight statistics popup automatically closes. A value of 0 means no timeout. | 30 |
| symbol-scale | Symbol scale | Symbol scale factor, scales map symbols as multiplier (see also `touch-scale`), | 1.0 |
| touch-drag-disconnected | Touch drag behaviour | If true, dragging a mission point on a touch screen will disconnect the marker from the path, and reconnect it when the drag is completed. This may improve touch drag behaviour. | true |
| touch-scale | Touch symbol scale | Symbol scale factor, scales map symbols as multiplier (for touch screens); (see also `symbol-scale`), | 1.0 |
| uc-mission-tags | Upper case mission XML tags | If true, MISSION, VERSION and MISSIONITEM tags are upper case (for interoperability with legacy Android applications) | false |
| uilang | Language Handling | "en" do everything as English (UI numeric decimal points, voice), "ev" do voice as English (so say 'point' for decimals even when shown as 'comma') | "" |
| use-fallback-video | Use fallback video player | If true, mwp will use a fallback video player, which will (a) work on Ubuntu 24.04 and derivatives and (b) work on Windows machines that crash with the default player. The downsides of the fallback player include (i) Higher latency for RTSP (c.2000ms) and (ii) no USB Video on Windows. | false |
| view-mode | UAV view mode | Options for model view map display | "inview" |
| vlevels | Voltage levels | Semi-colon(;) separated list of *cell* voltages values for transition between voltage label colours | "" |
| wp-dist-size | Font size (points) for OSD WP distance display | Font size (points) for OSD WP distance display | 56.0 |
| wp-spotlight | Style for the 'next waypoint' highlight | Defines RGBA colour for 'next way point' highlight | "#ffffff60" |
| wp-text-style | Style of text used for next WP display | Defines the way the WP numbers are displayed. Font, size and RGBA description (or well known name, with alpha) | "Sans 72/#ff000060" |
| zone-detect | Application to return timezone from location | If supplied, the application will be used to return the timezone (in preference to geonames.org). The application should take latitude and longitude as parameters. See samples/tzget.sh | "" |
