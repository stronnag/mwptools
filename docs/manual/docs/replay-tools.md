# Replay Tools

in order to replay log files, {{ mwp }} has a number of external dependencies, in particular the **flightlog2x** `fl2ltm` tool provided by the [bbl2kml](https://github.com/stronnag/bbl2kml) repository. As well as providing replay tools for {{ mwp }}, you also get the facility to generate  attractive animated KML / KMZ files for visualisation in **google-earth**.

<figure markdown>
![mode view](images/bbl2kml/v1.jpeg){: width="80%" }
<figcaption>Flight mode view</figcaption>
</figure>
<figure markdown>
![rssi view](images/bbl2kml/v2.jpeg){: width="80%" }
<figcaption>RSSI view</figcaption>
</figure>
<figure markdown>
![effic view](images/bbl2kml/v3.jpeg){: width="80%" }
<figcaption>Efficiency view</figcaption>
</figure>
!!! Note "Analysis"
    The RSSI view shows why the aircraft is playing "failsafe ping-pong" at the right extreme of flight

Binary packages are provided for many popular platforms.

## Blackbox replay

In order to replay blackbox logs, you additionally need [inav blackbox tools](https://github.com/iNavFlight/blackbox-tools), specifically `blackbox_decode`). Binary packages are provided for many popular platforms. The minimum required version in 0.4.4, the latest release is recommended.

## OpenTX / EdgeTX logs (Smartport)

OpenTX enables the storage of Smartport telemetry logs on a transmitter's SD-Card. These logs contain all the (Frsky) telemetry information transmitted from the flight controller.

{{ mwp }} can replay these logs, in a similar manner to the replay of Blackbox or mwp logs, albeit with less detail and typically at lower data rates.

* Enable Frsky telemetry on the FC
* Enable telemetry logging on the TX
* Post flight, transfer the log from the LOGS directory of the SD card to your computer
* Replay the log using the Replay OTX Log (or Load OTX Log for a "fast-forward" rendering)
* Limited support is available of TX logs from Ardupilot.

No addition software requirements.

## BulletGCSS Logs

Requires that {{ mwp }} is built with [MQTT support](mqtt---bulletgcss-telemetry).

No addition software requirements.

## Ardupilot logs

Requires Ardupilot's [mavlogdump.py](https://github.com/ArduPilot/pymavlink) and [dependencies](Replaying-Ardupilot-logs).

## mwp JSON logs

No addition requirements.
