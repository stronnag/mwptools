# Ground Control Station Features

## GCS Usage

### Basic functionality

* Real time tracking of vehicle via [telemetry](mwp-multi-procotol.md)
* Audio status reports
* OSD style WP information
* [Radar view](mwp-Radar-View.md) of other aircraft
* In picture [video feed display](mwp_video_player.md).

### OSD information

When flying waypoints, if the mission is also loaded into {{ mwp }}, {{ mwp }} can display some limited "OSD" information.

![mwp-osd](images/mwp-osd.png){: width="75%" }

Various settings (colour, items displayed etc.) are defined by [settings](mwp-Configuration.md#dconf-gsettings).

### GCS Location Icon

A icon representing the GCS location can be activated from the **View/GCS Location**" menu option.

By default, it will display a tasteful yellow / blue icon which one may drag around. It has a few other  purposes beyond showing some user specified location (but see [below](#radar)).

![GCS-Icon](images/gcs-icon.png)

If you don't like the icon, you can override it [by creating your own icon](mwp-Configuration.md#settings-precedence-and-user-updates).

* If `gpsd` is detected (on `localhost`), then the position will be driven by `gpsd`, as long as it has  a 3D fix.

* <span id="radar">The one  usage is when [inav-radar](mwp-Radar-View.md) is active; if the GCS icon is enabled (either by manual location or driven by `gpsd`), then rather than being a passive 'GCS' node, {{ mwp }} will masquerade as an 'INAV' node and advertise the GCS (icon) location to other nodes. This implies that you have sufficient LoRa slots to support this node usage.
</span>
* Another use is for {{ inav }} [Follow Me](mwp-follow-me.md) where the followed location can be driven by `gpsd`.
