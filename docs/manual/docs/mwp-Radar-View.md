# Radar View

{{ mwp }} supports the display of "radar" contacts. This provides a view of adjacent aircraft obtained from a number of sources:

* [inav-radar](https://www.rcgroups.com/forums/showthread.php?3304673-iNav-Radar-ESP32-LoRa-modems). inav radar works in conjunction with [inav](https://github.com/iNavFlight/inav) flight controllers to broadcast the location of UAS fitted with an ESP32 LoRa module. {{ mwp }} can listen to one of these modems in ground station mode to display the positions of the rest of the 'swarm' (up to 4 UAS); [technical / MSP details](#inav-radar).

* **Full size aircraft** reported by the MAVLink 'Traffic Report' message. An example is the [uAvionix PingRX](https://uavionix.com/products/pingrx/), a compact device that receives ADS-B location data from full sized aircraft and publishes the locations as MAVLink. For a ground based installation, this device has around a 40Km detection radius. [MAVLink ICD](https://uavionix.com/downloads/integration/uAvionix%20Ping%20Integration%20Guide.pdf).

* Proximity alerts (visual and audible) for manned (ADS-B) aircraft, based on planned or actual home location.

## mwp Configuration

{{ mwp }} can receive the 'radar' data over one or two connections, either or both may be active, and {{ mwp }} can receive and display 'own vehicle' telemetry (MSP, LTM or Smartpost), 'inav-radar' and 'MAVlink Traffic' data simultaneously. Radar data may be received over:

* The main serial port device (see [caveat](#using-the-main-serial-port) for inav-radar) or
* device(s) defined by the `radar-device` CLI or configuration parameter (MAVLink Traffic, inav-radar)

The `radar-device` option is defined by the standard {{ mwp }} naming scheme:

* A serial device node, with optional baud rate, e.g.:
    * `/dev/ttyACM0`, `/dev/ttyUSB4@567600`, `/dev/rfcomm3`
    * Serial defaults to 115200 baud, but may be set in the device name (@baudrate)
* A Bluetooth address (for BT bridges)
    * `00:0B:0D:87:13:A2`
* An IP address, e.g. for simulation, recording replays or serial multiplexer.
    * `udp://:30001` local UDP listener.

The specific (not shared with the main serial port) radar device(s) may be defined on the command line, or in the static command options file (`~/.config/mwp/cmdopts`):

 * `mwp --radar-device udp://:30001`
 * `$ cat ~/.config/mwp/cmdopts`

```
  # Default options for mwp
  # using udev rule to associate a specifc USB-TTL adaptor to a name
  --radar-device=/dev/pingRX@57600
```
Multiple devices may be defined, e.g.

* As separate options, `--radar-device=/dev/pingRX@57600 --radar-device= /dev/inavradar@115200`
* As a comma separated list: `--radar-device=/dev/pingRX@57600,/dev/inavradar@115200`

Any bespoke `radar-device` is started automatically on startup (or when it shows up). It is not managed via the serial `Connect` button.

## Using the main serial port

The main serial port may be used for MavLink Traffic without any further configuration. For inav-radar, to use the main msp port for inav-radar (vice using `--radar-device`), it is still necessary to add a command option to {{ mwp }}; it needs to told to relax the default inbound MSP direction check.

This is enabled as
```
mwp --relaxed-msp
```
which should be 'mainly harmless' for normal operations. It's entirely acceptable to put this in `~/config/mwp/cmdopts` to make it the default, as the protocol check dilution is slight.

## Settings

The following `dconf` setting affect the radar function:

| Setting | Usage |
| ------- | ----- |
| `radar-list-max-altitude` | Maximum altitude (metres) to show targets in the radar list view; targets higher than this value will show only in the map view. Setting to 0 disables. Note that ADS-B altitudes are AMSL (or geoid) |
| `radar-alert-altitude` | Target altitude (metres) below which ADS-B proximity alerts may be generated. Requires that 'radar-alert-range' is also set (none zero). Setting to 0 disables. Note that ADS-B altitudes are AMSL (or geoid). |
| `radar-alert-range` | Target range (metres) below which ADS-B proximity alerts may be generated. Requires that 'radar-alert-altitude' is also set (none zero). Setting to 0 disables. |

Note that proximity alerts require that both the `radar-alert-altitude` and `radar-alert-range` values are set, and that there is a planned or actual home location.

## Usage

Once the radar interface is open, radar tracks are displayed on the map and in a list available from the "View -> Radar View' menu option.

* The list view is sort-able on the `Id`, `Status`, `Last` (time) and `Range` columns.
* The map visualisation may be toggled by the `Hide Tracks` (`Show Tracks`) button.
* List and map views are updated in (near) real time.
* Preference for display units are used for positions, altitude and speed.

### Name

| Type | Usage |
| ---- | ----- |
| inav-radar | Node Id (typically 'A' - 'D') |
| Traffic Report | Callsign if reported, otherwise [ICAO number] |

### Status

Radar contacts have one of the following status values:

| Status | Explanation |
| ------ | ----------- |
| Undefined | Not shown in list or on the map |
| Stale | The last contact was more that 120s previous. Displayed in the list and shown on the map with reduced intensity or an inav-radar node has'lost' status |
| Armed | An active inav-radar contact |
| ADS-B | A live MAVLink Traffic report |
| Hidden | A MAVLink Traffic contact is between 5 and 10 minutes old. It remains in the list but is not displayed in the map. MAVLink Traffic Report tracks are removed from the list (and internal storage) after 10 minutes inactivity. inav-radar ground station |

Stale / 'Lost' inav-radar contacts do not expire, as they may relate to a lost model.

The number displayed after the status text is:

| Type | Usage |
| ---- | ----- |
| inav-radar | The link quality |
| Traffic Report | Time since last communication in seconds |

## Examples

* Proximity Alerts
* Live and stale aircraft
* Aircraft tooltip
* Mission Plan
* List view

### Live ADS-B and simulated inav targets, with proximity alerts (range < 3000m).

![radar-alerts](images/mwp-radar-alert.png){: width="80%" }

### Local manned aircraft view over Florida (May 2020).

![Florida-may-2020](images/florida-2020-05.png){: width="80%" }

### Simulated inav radar view

![inav-radar-sim](images/mwp-inav-radar.png){: width="60%" }

## Simulators

There are simulators for both inav-radar and MAVLink 'Traffic Report' (e.g. uAvionix PingRX) in the `mwptools/samples/radar` directory.

## Changing the Radar Symbols

Any map symbol used by {{ mwp }} can be changed by the user; in the image above, the inav radar node symbol has been changed from the default stylised inav multirotor to a smaller version of the mission replay "paper plane" symbol as follows:

* All the default {{ mwp }} icons / map symbols can be found in `$prefix/share/mwp/pixmaps/` (e.g. `~/.local/share/mwp/pixmaps` for a "local" installation).
* Create your own icon with the equivalent name in `~/config/mwp/pixmaps/`.

The icons in `~/config/mwp/pixmaps/` are found before the defaults.

```
mkdir -p `~/config/mwp/pixmaps
# copy the preview image
cp /usr/share/mwp/pixmaps/preview.png  ~/config/mwp/pixmaps/
# (optionally) resize it to 32x32 pixels
mogrify -resize 80% ~/config/mwp/pixmaps/preview.png
# and rename it, mwp doesn't care about the 'extension', this is not MSDOS:)
mv  ~/config/mwp/pixmaps/preview.png  ~/config/mwp/pixmaps/inav-radar.svg
# and verify ... perfect
file ~/.config/mwp/pixmaps/inav-radar.svg
/home/jrh/.config/mwp/pixmaps/inav-radar.svg: PNG image data, 32 x 32, 8-bit/color RGBA, non-interlaced
```
## Protocol documentation

###  MAVLink 'Traffic Report' (e.g. uAvionix PingRX)

The MAVLink implementation is [comprehensively documented](https://uavionix.com/downloads/integration/uAvionix%20Ping%20Integration%20Guide.pdf) by the vendor.

### inav radar

The following is required by a device wishing to act as a ground node (it either masquerades as an inav FC, or declares itself a GCS)

* Receive and respond to the following MSP data requests:
    * MSP_FC_VARIANT (responding as `INAV` or (from 2021/05/06) `GCS` for generic ground control stations).
    * MSP_FC_VERSION (in `INAV` and `GCS` modes)
    * MSP_NAME (in `INAV` and `GCS` modes)
    * MSP_STATUS (in `INAV` mode)
    * MSP_ANALOG (in `INAV` mode)
    * MSP_BOXIDS (in `INAV` mode)
    * MSP_RAW_GPS (in `INAV` mode)
* Receive unsolicited
    * MSP2_COMMON_SET_RADAR_POS

Note that the device firmware assumes that MSP buffer sizes are "as specification"; exceeding the expected message buffer size may crash the device (mea culpa).

In `GCS` mode, the node is passive; it does not use a LoRa slot and does not attempt to broadcast a location. In `INAV` mode, the node takes up a LoRa slot and is expected to reply to the additional MSP queries.

{{ mwp }}'s behaviour is defined by the [GCS Location](gcs-features.md#gcs-location-icon)

* If the [GCS Location](gcs-features.md#gcs-location-icon) is defined (when the radar device is iniitilised, then {{ mwp }} will respond as `INAV` and return the [GCS Location](gcs-features.md#gcs-location-icon), which may be driven by gpsd if required.
* Otherwise, mwp will respond as a passive `GCS`.
