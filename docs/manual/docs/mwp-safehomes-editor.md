# Safehome and Auto-land

One of the great features of {{ inav }} 2.6 was the `safehome` capability. The user can define of set of up to eight locations, and if any of these is within 200m (configurable up to 650m in {{ inav }} 2.7), then that is used as the home location for RTH (and RTH failsafe).

## INAV setting

`safehome` is set in {{ inav }} using the CLI, (note more recent Configurators also have a UI);  here's an example:

    # safehome
    safehome 0 1 508047750 -14948970
    safehome 1 1 509102384 -15344850
    safehome 2 1 509390336 -14613540
    safehome 3 1 509149619 -15337365
    safehome 4 0 508054891 -14961431
    safehome 5 0 543545392 -45219430
    safehome 6 0 540954148 -47328458
    safehome 7 0 0 0

As you see, it's not too user friendly; the parameters are

* Index (0 - 7)
* Status (0 = don't use, 1 = can use)
* Latitude as degrees * 10,000,000 (i.e. 7 decimal places)
* Longitude as degrees * 10,000,000 (i.e. 7 decimal places)

It can be error prone to get locations into the correct format, particularly when a common source (Google Maps) only provides 6 decimal places of precision.

## mwp solution

### Graphical User Interface

!!! note "Legacy Images"
    The images this section are from legacy mwp, however the capability is the same.

Note: Since mwp 7.32.?, mwp provides additional fields for the Autoland function that first appeared in INAV 7.1.0.

{{ mwp }} now offers a `Safe Homes` menu option:

![mwp safehome](images/mwp-safehome-menu.png){: width="25%" }

This will launch the `Safe Home` window:

![mwp safehome](images/mwp-safehome-usage.png){: width="50%" }

From here it is possible to:

* Load safehomes from a file in CLI format. A CLI diff or dump can be  used.
* Save safehomes to a file in CLI format. If a CLI diff or dump is selected, then only the `safehome` and `fwapproach` stanzas are changed; other information in the diff / dump is preserved.
* Display safehomes on the map. Active safehomes are displayed with greater opacity than inactive locations.
* Change the status (active, inactive). If a previously unused item is enabled, an icon is placed on the centre of the map for positioning.
* Clear (unset) one or all safehomes.
* Upload and Download `safehome` and `fwapproach` data to/from the flight controller.
* Manage INAV 7.1.0+ Autoland data

Clicking the "Edit" button at the end of row enables editing FWA parameters:

![mwp safehome-edit](images/mwp-sh1.png){: width="50%" }

Note that editing functions are only available when the `Safe Homes` window is active; if the windows is dismissed with icons displayed, then the icons remain on the map, but are not editable.

### Display safehomes at startup

It also is possible to set a `gsettings` key to define a file of safehomes to load at startup, and optionally display (readonly) icons.

    gsettings set org.stronnag.mwp load-safehome ~/.config/mwp/safehome.txt,Y

This sets the default safehomes file to `~/.config/mwp/safehome.txt` and the appended `,Y` means display the icons on the map.

If the file also contains `fwapproach` data, that will be applied as well.

If the name part is set to `-FC-`, then the safehomes will be loaded from the flight controller, for example:

    gsettings get org.stronnag.mwp load-safehome
	'-FC-,Y'

### Example

The image below shows a blackbox replay. Note that the flight home location (brown icon) is coincident with the pale orange safehome icon.

![mwp safehomes replay](images/mwp-safehomes-replay.png){: width="50%" }

### FW Approach (FWA) visualisation

Please note that for the display of the geometry of the FWA, {{ mwp }} uses the same rules as the flight controller; in particular the length of "base leg / dog leg" depends two CLI parameters, `nav_fw_land_approach_length`, `nav_fw_loiter_radius`. These are not part of the safe home (or mission) definition, rather they are properties of the model (and thus are persisted in a CLI `diff` file).

{{ mwp }} can load these properties from a CLI `diff`/`dump` format file, as well as other [CLI artefacts](running.md#cli-files).

In particular, the length of the "base leg / dog leg" is the **maximum** of:

* `nav_fw_land_approach_length / 2` or
* `nav_fw_loiter_radius * 4`

For example, in the first image the user had set `nav_fw_land_approach_length` to 150m (for a small, agile plane) but had accidentally left the `nav_fw_loiter_radius` at the default of `75m`. The excessive radius dominates and gives an unacceptable geometry:

![fwa1](images/fwa-ex1.png)

Setting the radius to a more appropriate value for the model (40m) results in a much more acceptable geometry (still dominated by the loiter radius).

![fwa2](images/fwa-ex2.png)

In summary, in order to display FWA accurately for either safe homes or missions, it is advisable to provide a CLI `diff` format file containing at a minimum, `set` values for `nav_fw_land_approach_length` and `nav_fw_loiter_radius`. For the above example:

```
set nav_fw_loiter_radius = 4000
set nav_fw_land_approach_length = 15000
```
