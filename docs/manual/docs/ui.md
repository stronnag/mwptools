# User interface

## Main Window

![main](images/main-window.png){: width="100%" }

The {{ mwp }} main window and the main user interface elements are:

1. [Menu bar](#menu-bar-1). The menu options are described later.
2. [Map and Mission](#map-and-mission-settings-2) settings
3. [Communications and telemetry settings](#communications-and-telemetry-settings-3)
4. [Map window](#map-area-4)
5. [Dock Bar](#dock-bar-5)
6. [Dock Items (Docklets)](#docklets-6)
7. [Mouse location](#location-7) (user preference units, cursor or map centre location)
8. [Flight controller](#fc-information-8) information
9. [Sensor status and flight timer](#sensors-and-flight-status-9)

In the sections that follow, there will be a brief summary of each part; more detail will then provided in subsequent sections.

## Menu Bar (1)

The following tables summarise the available menu options. Where usage is not obvious, operation will be described later on.

### File Menu

| Item                                         | Usage                                                                                                                                                         |
| ----                                         | -----                                                                                                                                                         |
| Open Mission                                 | Offers a dialog to [open a mission file](inav-4.0-multi-missions.md#open-mission-file)                                                                           |
| Append Mission file                          | [Appends a mission](inav-4.0-multi-missions.md#append-mission-file) to the current mission set (creates a multi-mission element)                                                                                    |
| Save Mission                                 | Saves the mission to the current mission file, overwriting any extant content                                                                                 |
| Save Mission As                              | Saves the mission to a user selected file. For a [multi-mission](inav-4.0-multi-missions.md#save-as-mission-file) the user can choose not to save specified mission segments.                                                                                                                     |
| Download Mission from FC                     | [Downs a (multi-) mission](inav-4.0-multi-missions.md#upload-download-menu-options) from the flight controller                                                                                                           |
| Upload Mission to FC > Upload Active Mission | [Uploads the current mission segment](inav-4.0-multi-missions.md#upload-download-menu-options) to the flight controller                                                                                                  |
| Upload Mission to FC > Upload All Missions   | [Uploads all mission segments](inav-4.0-multi-missions.md#upload-download-menu-options) to the flight controller                                                                                                         |
| Restore Mission from EEPROM                  | Restores the EEPROM stored mission from the flight controller                                                                                                 |
| Save Mission to EEPROM                       | Saves the current mission segment(s) to the flight controller. The current active mission segment (in a multi-mission) is set as the active mission in the FC |
| Replay mwp log                               | Replay a mwp (JSON) log file                                                                                                                                  |
| Load mwp log                                 | Loads a mwp (JSON) log file (i.e, as fast as practical, ignoring timings)                                                                                     |
| Replay blackbox log                          | Replays a Blackbox log file                                                                                                                                   |
| Load blackbox log                            | Loads a Blackbox log file (i.e, as fast as practical, ignoring timings)                                                                                       |
| Replay OTX log                               | Replays an OpenTX / EdgeTX CSV log file. (Also BulletGCSS and Ardupilot logs where available)                                                                                                                       |
| Load OTX log                                 | Loads an OpenTX / EdgeTX CSV log file. (Also BulletGCSS and Ardupilot logs where available)                                                                                                                         |
| Stop Replay                                  | Stops a running replay                                                                                                                                        |
| Static Overlay > Load                        | Loads a static KML format overlay file                                                                                                                        |
| Static Overlay > Remove                      | Removes a loaded KML file from the display                                                                                                                    |
| Safe Homes                                   | Invokes the {{inav }} [safe-home editor](mwp-safehomes-editor.md)                                                                                                |
| Quit                                         | Cleanly quits the application, saving the display layout                                                                                                      |

### Edit Menu

| Item | Usage |
| ---- | ----- |
| Set FollowMe Point | Displays the [Follow Me](mwp-follow-me.md) dialogue |
| Preferences | Displays the [preferences](misc-ui-elements.md#preferences) dialogue |
| Multi Mission Manager | Display the multi-mission dialogue to remove segments from a multi-mission |
| CLI serial terminal | Displays the {{ inav }} CLI using the current connection |
| Nav Config | (Legacy MW) MW Nav Configuration |
| Get FC Mission Info | Display the mission status from a connected FC |
| Seed current map | Shows a dialogue to seed the map cache for offline (field) use |
| Reboot FC | Reboots a connected flight controller |
| Audio Test | Reads out the {{ mwp }} version number as an audio test |

### View Menu

| Item | Usage |
| ---- | ----- |
| Zoom to Mission | Zooms the map to the currently loaded mission |
| Set location as default | Sets the current location as the default (startup) location |
| Centre on position ... | Shows the ["Centre on Position" selector and "favourite places" editor"](misc-ui-elements.md#favourite-places) |
| Map Source | Displays a dialogue with information on the selected map source |
| GPS Statistics | Displays FC GPS status (rate, packets, errors, timeouts, HDOP/EPV/EPH) |
| Mission Editor| Adds the Mission Editor (tabular view) to the dock (default) |
| MW Nav Status | Adds the (legacy MW) Nav Status docklet to the dock |
| GPS Status | Adds the (legacy MW) GPS Status docklet to the dock |
| Radio Status | Adds the radio status docklet to the dock (default) |
| Battery Monitor | Adds the Battery  Status docklet to the dock (default) |
| Telemetry Status | Adds the Telemetry Status docklet to the dock |
| Artificial Horizon | Adds the Artificial Horizon docklet to the dock (default) |
| Direction View | Adds the Direction View (mag v. GPS) docklet to the dock |
| Flight View | Adds the Flight View docklet to the dock (default) |
| Vario View | Adds the Vario docklet to the dock ||
| Radar View | Displays the [Radar (inav radar / ADS-B) view](mwp-Radar-View.md) |
| Telemetry Tracker | Displays the [Telemetry Tracker UI](mwp-telemetry-tracker.md) |
| Flight Statistics | Display the flight statistic dialogue (also automatic on disarm) |
| Layout Manager > Save | Saves the current dock layout |
| Layout Manager > Restore | Restores a saved dock layout |
| Video Stream | Opens the (live) video stream window |
| GCS Location | Displays the indicative [GCS location icon](gcs-features.md#gcs-location-icon) |

### Help Menu

| Item | Usage |
| ---- | ----- |
| Shortcut keys list | Displays the short cut keys list |
| About |  Displays version, author and copyright information |

## Map and Mission Settings (2)

A number of different map provides are available. {{ mwp }} offers the mapping library (`libchamplain`) defaults, Bing Maps (Bing Proxy) using a bespoke {{ mwp }} API key, and [user defined options](mwp-Configuration.md#sourcesjson), for example [anonymous maps](Black-Ops.md).

The zoom level may be selected from the control here, or by zooming the map with the mouse wheel.

The **+Edit WPs** button enables mission edit mode (click on the map to create a WP, drag to move, right mouse button for properties). Graphical WP editing may be augmented by the table orientated [mission table view](mission-editor.md), which allows additional control (altitude, speed, special functions, for example [fly-by-home](Fly-By-Home-waypoints-(inav-4-new-feature).md) waypoints).

The "Active Mission" drop down supports {{ inav }} 4.0+ [multi-mission](inav-4.0-multi-missions.md). There is also a **multi-mission manager** under the **Edit** menu.

## Communications and telemetry settings (3)

There is a (blue "!" in the example) 'navigation safe' status icon. If this icon is shown (i.e. navigation is _unsafe_, then clicking on the item will provide more information:

![navunsafe](images/nav-unsafe.png){: width="20%" }

The **Device** drop-down offers detected and pre-set (**Preferences**) devices for the FC / telemetry port. The device syntax is described the [Device and Protocol definition](mwp-multi-procotol.md) chapter.

The **Protocol Selection** drop-down (showing **Auto** in the reference image) allows the user to provide a hint as to communication protocols available on **Device**. These are further described in the [Device and Protocol definition](mwp-multi-procotol.md) article.

The **Connect / Disconnect** button connects / disconnects the displayed device.

The **auto** button causes {{ mwp }} to automatically attempt to connect to the nominated device.

## Map Area (4)

The map area displays the currently selected map at the desired zoom level. The map may be managed using familiar controls (drag, scroll wheel etc).

!!! info "Graphics Requirement"

    The map API used my {{ mwp }} requires OpenGL / 3D accelerated graphics. Performance with software rendering may disappointing and / or CPU intensive.

## Dock Bar (5)

The **Dock Bar** contains essentially minimised [**Docklets**](#docklets-6), selected from the **View** menu. In the illustration, these are the **Vario** view, **Telemetry** statistics, and **Mission Editor**. Hovering the mouse over the icon will reveal its function:

![dockfunc](images/dockavail.png){: width="20%" }

## Docklets (6)

**Docklets** are display items that can be docked, iconised, hidden or displayed in floating windows. See [Dock Management](dock.md). In the **main window screen shot** (left to right, top to bottom) we have:

* Radio status (RSSI or LQ)
* Artificial horizon
* Direction Status (Heading (Position Estimator/Compass v. GPS). Useful to diagnose mag EMF interference on multi-rotors).
* Flight View. General geo-spatial information.
* Battery status. Current usage is also shown when available.

## Location (7)

The location (of the mouse pointer), [user setting](mwp-Configuration.md#dconf-gsettings) `pos-is-centre` for either mouse pointer or map centre, and display format (**Preferences**).

## FC Information (8)

Displays the firmware, version and build with API information, profile and flight mode.

## Sensors and flight status (9)

* **Follow** : [user setting](mwp-Configuration.md#dconf-gsettings) `auto-follow`. whether the map always displays the aircraft icon and tracks (requires GPS).
* **In View** : Scrolls the map to keep the aircraft in view. The behaviour is defined by the
[user setting](mwp-Configuration.md#dconf-gsettings) `use-legacy-centre-on`
    * `use-legacy-centre-on` = `false` (default): The map is only panned when the vehicle would otherwise be off-screen.
	* `use-legacy-centre-on` = `true` : The vehicle is always centre of the screen and the map pans as required.
* **Logger** : Generate mwp logs (JSON format).
* **Audio** : [user setting](mwp-Configuration.md#dconf-gsettings) `audio-on-arm`. Whether to "speak" status information.

The green / red bars show gyro / acc / baro / mag / gps / sonar sensor status. If a required sensor fails, a map annotation will be displayed, together with an audible alarm.

![sensorfail](images/sensorfail.png){: width="40% "}
