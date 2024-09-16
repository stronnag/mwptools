# DBus API

## Introduction

{{ mwp }} provides a Dbus API to permit remote control or monitoring of mwp by third party applications.

Dbus is a common Linux API for inter-process communications, and can be used from most programming languages. `mwptools/src/samples` provides examples in `python`, `ruby` and `bash`.

It is intended that that the `ruby` examples cover the majority of the  API and provide canonical examples of usage.

As this is a developer topic, please raise GitHub issues if clarification is needed or you have a use case that would benefit from extending the API.

Please also note that the definitive definition of the DBus API is provided by DBus inspection.

## DBus object and interface

The mwp Dbus API exists on the session bus when mwp is running.

* Object Path: `/org/stronnag/mwp`
* Interface: `"org.stronnag.mwp"`

## Flight Status and geo-location information

A set of APIs is provided for synchronous and asynchronous (signals, event by event) notification of vehicle status and location. A use case might be to drive an antenna tracker.

### Flight status and geo-location methods

#### GetModeNames

Returns human-readable names for the FC 'mode' returned by `GetState`, as an array of strings. The size of the array is the return value. These are effectively LTM modes.

    int GetModeNames(out string[] states_names)

    <method name="GetModeNames">
      <arg type="as" name="names" direction="out"/>
      <arg type="i" name="result" direction="out"/>
    </method>

#### GetState

Returns the FC 'state' and 'mode'. state 0 if unarmed. Human-readable mode names are provided by(sic) `GetModeNames()`.

    void GetState(out int state, out int mode)

    <method name="GetState">
      <arg type="i" name="state" direction="out"/>
      <arg type="i" name="mode" direction="out"/>
    </method>

#### GetHome

Returns the home location as latitude (WGS84 decimal degrees),  longitude (WGS84 decimal degrees) and relative altitude (metres, which should always be 0).


    void GetHome(out double latitude, out double longitude, out int32 altitude)

    <method name="GetHome">
      <arg type="d" name="latitude" direction="out"/>
      <arg type="d" name="longitude" direction="out"/>
      <arg type="i" name="altitude" direction="out"/>
    </method>

#### GetLocation

Returns the vehicle location as latitude (WGS84 decimal degrees),  longitude (WGS84 decimal degrees) and relative altitude (metres).

    void GetLocation(out double latitude, out double longitude, out int32 altitude)

    <method name="GetLocation">
      <arg type="d" name="latitude" direction="out"/>
      <arg type="d" name="longitude" direction="out"/>
      <arg type="i" name="altitude" direction="out"/>
    </method>

#### GetSats

Returns the number of satellites and the fix type (0=nofix, 1=undefined, 2=2D fix, 3=3D fix).

    void GetSats(out uint8 number_satellites, uint8 fix_type)

    <method name="GetSats">
      <arg type="y" name="nsats" direction="out"/>
      <arg type="y" name="fix" direction="out"/>
    </method>

#### GetVelocity

Returns the vehicle speed (m/s) and course (degrees), GPS provided.


    void GetVelocity(out uint32 speed, out uint32 course)

    <method name="GetVelocity">
      <arg type="u" name="speed" direction="out"/>
      <arg type="u" name="course" direction="out"/>
    </method>

#### GetPolarCoordinates

Returns the vehicle location as polar coordinates relative the home position: Range (m), Bearing (degrees) **from home to vehicle**, azimuth (elevation angle, degrees).

    void GetPolarCoordinates(out uint32 range, out uint32 direction, out uint32 azimuth)

    <method name="GetPolarCoordinates">
      <arg type="u" name="range" direction="out"/>
      <arg type="u" name="direction" direction="out"/>
      <arg type="u" name="azimuth" direction="out"/>
    </method>

#### GetWaypointNumber

Returns the next WP number (en-route to) or -1 if not flying WPs.

    int GetWaypointNumber()

    <method name="GetWaypointNumber">
      <arg type="i" name="result" direction="out"/>
    </method>

### Flight status and geo-location signals

A number of signals (asynchronous event by event notifications) are issues for changes in state and location. This avoids applications having to poll for changes. In general, the data returned is that for the eponymous Get* methods.

All location signals may be rate limited by the `DbusPosInterval` property in order to avoid excessive DBus traffic.

#### HomeChanged

Notifies that the home position has changed.

    signal void HomeChanged (double latitude, double longitude, int altitude)

    <signal name="HomeChanged">
      <arg type="d" name="latitude"/>
      <arg type="d" name="longitude"/>
      <arg type="i" name="altitude"/>
    </signal>

#### LocationChanged
Notifies that the vehicle position has changed (geographic coordinates).

    signal void location_changed (double latitude, double longitude, int altitude)

    <signal name="LocationChanged">
      <arg type="d" name="latitude"/>
      <arg type="d" name="longitude"/>
      <arg type="i" name="altitude"/>
    </signal>

#### PolarChanged

Notifies that the vehicle position has changed relative to home (polar coordinates).

    signal void polar_changed(uint32 range, uint32 direction, uint32 azimuth)

    <signal name="PolarChanged">
      <arg type="u" name="range"/>
      <arg type="u" name="direction"/>
      <arg type="u" name="azimuth"/>
    </signal>

#### VelocityChanged

Notifies that the vehicle velocity (course or speed) has changed.

    signal void velocity_changed(uint32 speed, uint32 course)

    <signal name="VelocityChanged">
      <arg type="u" name="speed"/>
      <arg type="u" name="course"/>
    </signal>

#### StateChanged

Notifies that the vehicle 'state' has changed.

    signal void StateChanged(int32 state)

    <signal name="StateChanged">
      <arg type="i" name="state"/>
    </signal>

#### SatsChanged

Notifies that the satellite status has changed.

    signal void SatsChanged(uint8 nsats, uint8 fix)

    <signal name="SatsChanged">
      <arg type="y" name="nsats"/>
      <arg type="y" name="fix"/>
    </signal>

#### WaypointChanged

Notifies that the current WP number has changed.

    signal void WaypointChanged(int32 wp)

    <signal name="WaypointChanged">
      <arg type="i" name="wp"/>
    </signal>

### Application Status
#### Quit

The `Quit` signal is issued when mwp exits, allowing a dependent application to close down gracefully or take action to wait for the bus to reappear.

    Quit()

    <signal name="Quit">
    </signal>
## Properties

### DbusPosInterval

    uint dbus_pos_interval

Defines rate limiting for all position related signals. The value represents the minimum update interval in 0.1s intervals.

* 0 disables rate limiting
* 2 is the default, and matches the best LTM rate of 5Hz
* a large value (e.g. 999999, greater than a realistic flight time), would effectively disable event by event positional updates.

## Serial Port and Mission management

A set of APIs is provided for remote serial port and mission management.

## Serial Ports
### GetDevices

The `GetDevices` API returns a list of the serial devices known to the mwp instance, as an array of strings.


    void GetDevices(out string[]device_names)

    <method name="GetDevices">
      <arg type="as" name="devices" direction="out"/>
    </method>

### ConnectionStatus

The `ConnectionStatus` API returns a boolean status as to whether `mwp` is connected to a serial device, and if connected, the name of the device.

    bool ConnectionsStatus(out string device_name)

    <method name="ConnectionStatus">
      <arg type="s" name="device" direction="out"/>
      <arg type="b" name="result" direction="out"/>
    </method>

### ConnectDevice

The `ConnectDevice` API attempts connection to the given device, and returns the status of the operation (`true` => connected).

    bool ConnectDevice(string device_name)

    <method name="ConnectDevice">
      <arg type="s" name="device" direction="in"/>
      <arg type="b" name="result" direction="out"/>
    </method>

## Mission Management

Somewhat inconsistent set of mission management APIs. Note these are not yet multi-mission aware.

### ClearMission

Clears the current mission from mwp.

    void ClearMission()

    <method name="ClearMission">
    </method>

### SetMission

Opens a mission in mwp from an XML or JSON document, returns the number of mission points.

    int SetMission(string mission)

    <method name="SetMission">
      <arg type="s" name="mission" direction="in"/>
      <arg type="u" name="result" direction="out"/>
     </method>

### LoadMission

Opens a mission in mwp from an mission file, returns the number of mission points.

    int LoadMission(string filename)

    <method name="LoadMission">
      <arg type="s" name="filename" direction="in"/>
      <arg type="u" name="result" direction="out"/>
    </method>

### UploadMission

Loads the current mwp mission into the flight controller, optionally saving to it EEPROM. Returns the number of mission points.

    int UploadMission(bool to_eeprom)

    <method name="UploadMission">
      <arg type="b" name="to_eeprom" direction="in"/>
      <arg type="i" name="result" direction="out"/>
    </method>

## Examples
* `samples/mwp-dbus-test.sh`
* `samples/mwp-dbus.rb`
* `samples/mwp-dbus.py`
* `samples/mwp-dbus-loc.rb`
* `samples/mwp-dbus-loc.py`
* `samples/mwp-dbus-to-gpx.rb`

## Introspection

Not withstanding the state of the documentation, it is possible introspect the API. Note that mwp must be running for the API to exist.
The document returned by DBus introspection **is** the definitive definition of the API.


    # Note samples/mwp-dbus-loc.rb also provides introspection.
    $ samples/mwp-dbus-test.sh introspect
    <!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
                          "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
    <!-- GDBus 2.60.3 -->
    <node>
      <interface name="org.freedesktop.DBus.Properties">
        <method name="Get">
          <arg type="s" name="interface_name" direction="in"/>
          <arg type="s" name="property_name" direction="in"/>
          <arg type="v" name="value" direction="out"/>
        </method>
        <method name="GetAll">
          <arg type="s" name="interface_name" direction="in"/>
          <arg type="a{sv}" name="properties" direction="out"/>
        </method>
        <method name="Set">
          <arg type="s" name="interface_name" direction="in"/>
          <arg type="s" name="property_name" direction="in"/>
          <arg type="v" name="value" direction="in"/>
        </method>
        <signal name="PropertiesChanged">
          <arg type="s" name="interface_name"/>
          <arg type="a{sv}" name="changed_properties"/>
          <arg type="as" name="invalidated_properties"/>
        </signal>
      </interface>
      <interface name="org.freedesktop.DBus.Introspectable">
        <method name="Introspect">
          <arg type="s" name="xml_data" direction="out"/>
        </method>
      </interface>
      <interface name="org.freedesktop.DBus.Peer">
        <method name="Ping"/>
        <method name="GetMachineId">
          <arg type="s" name="machine_uuid" direction="out"/>
        </method>
      </interface>
      <interface name="org.mwptools.mwp">
        <method name="GetStateNames">
          <arg type="as" name="names" direction="out"/>
          <arg type="i" name="result" direction="out"/>
        </method>
        <method name="GetVelocity">
          <arg type="u" name="speed" direction="out"/>
          <arg type="u" name="course" direction="out"/>
        </method>
        <method name="GetPolarCoordinates">
          <arg type="u" name="range" direction="out"/>
          <arg type="u" name="direction" direction="out"/>
          <arg type="u" name="azimuth" direction="out"/>
        </method>
        <method name="GetHome">
          <arg type="d" name="latitude" direction="out"/>
          <arg type="d" name="longitude" direction="out"/>
          <arg type="d" name="altitude" direction="out"/>
        </method>
        <method name="GetLocation">
          <arg type="d" name="latitude" direction="out"/>
          <arg type="d" name="longitude" direction="out"/>
          <arg type="d" name="altitude" direction="out"/>
        </method>
        <method name="GetState">
          <arg type="i" name="result" direction="out"/>
        </method>
        <method name="GetSats">
          <arg type="y" name="nsats" direction="out"/>
          <arg type="y" name="fix" direction="out"/>
        </method>
        <method name="SetMission">
          <arg type="s" name="mission" direction="in"/>
          <arg type="u" name="result" direction="out"/>
        </method>
        <method name="LoadMission">
          <arg type="s" name="filename" direction="in"/>
          <arg type="u" name="result" direction="out"/>
        </method>
        <method name="ClearMission">
        </method>
        <method name="GetDevices">
          <arg type="as" name="devices" direction="out"/>
        </method>
        <method name="UploadMission">
          <arg type="b" name="to_eeprom" direction="in"/>
          <arg type="i" name="result" direction="out"/>
        </method>
        <method name="ConnectionStatus">
          <arg type="s" name="device" direction="out"/>
          <arg type="b" name="result" direction="out"/>
        </method>
        <method name="ConnectDevice">
          <arg type="s" name="device" direction="in"/>
          <arg type="b" name="result" direction="out"/>
        </method>
        <signal name="HomeChanged">
          <arg type="d" name="latitude"/>
          <arg type="d" name="longitude"/>
          <arg type="i" name="altitude"/>
        </signal>
        <signal name="LocationChanged">
          <arg type="d" name="latitude"/>
          <arg type="d" name="longitude"/>
          <arg type="i" name="altitude"/>
        </signal>
        <signal name="PolarChanged">
          <arg type="u" name="range"/>
          <arg type="u" name="direction"/>
          <arg type="u" name="azimuth"/>
        </signal>
        <signal name="VelocityChanged">
          <arg type="u" name="speed"/>
          <arg type="u" name="course"/>
        </signal>
        <signal name="StateChanged">
          <arg type="i" name="state"/>
        </signal>
        <signal name="SatsChanged">
          <arg type="y" name="nsats"/>
          <arg type="y" name="fix"/>
        </signal>
        <signal name="Quit">
        </signal>
        <property type="u" name="DbusPosInterval" access="readwrite"/>
      </interface>
    </node>
