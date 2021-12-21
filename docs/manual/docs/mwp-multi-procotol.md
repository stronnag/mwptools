# "Serial" device support

mwp supports a number of different data transports for "serial" protocols:

* Wired serial devices (USB TTL (VCP) etc.)
* Bluetooth
* IP (UDP and TCP)
* "Special" (e.g. BulletGCSS via the MQTT protocol).

Each of these requires a specific device name and _may_ require a protocol selection.

## Serial devices

Serial devices are defined by the operating system device node name and optionally include an embedded baud rate, for example:

```
# Linux, USB seral
/dev/ttyACM0
# Linux, USB serial with baud rate
/dev/ttyUSB0@57600
# Linux, RFCOM Bluetooth
/dev/rfcomm1
```
```
# FreeBSD
/dev/cuaU0
```
## Bluetooth

Bluetooth may be specified by either an `rfcomm` device node (`/dev/rfcommX`) or by the device address (`BD_ADDR`, Linux only):

```
# BT RFCOMM device node
/dev/rfcomm1
/dev/rfcomm1@57600
# BT device address (note here baud rate is immaterial)
35:53:17:04:07:27
```

## IP protocols (UDP and TCP)

mwp uses a pseudo-URL format for TCP and UDP connections `udp://host:‍port` and `tcp://host:‍port` (where `host` is either a hostname or an IP address as required).

Typically on one side of the connection you'll provide a hostname /IP and on the other you won't (as it can get the peer address from the first data packet).

Assuming the required UDP port is 43210

if mwp is the "listener" (doesn't need, *a priori*, to know the address of peer), set the "Device" to:
```
udp://:43210
```
i.e. the host part is empty.

If the remote device / application is the listener, and we know its IP address; in the following example "192.168.42.17", set the "Device" to:
```
udp://192.168.42.17:43210
```

Note that for TCP, mwp only supports the latter form (it expects to be the TCP client).

## Special Cases

### MQTT / BulletGCSS

See the [mwp's MQTT support](mqtt---bulletgcss-telemetry) article for a detailed description of the URI format:
```
mqtt://[user[:pass]@]broker[:port]/topic[?cafile=file]
```

### WSL UDP bridge

As WSL does not support serial connections, mwp provides a bespoke serial / UDP bridge using the pseudo-device name `udp://__MWP_SERIAL_HOST:17071`. See the [WSL article](mwp-in-Windows-11---WSL-G) for more detail.

## Multi Protocol selection

### Overview

From 4.317.587 (2021-11-21), mwp does away with some of the weirdness around serial protocols (e.g. having to separately specify `--smartport` in order to use S-Port telemetry).

Instead, there is now a protocol drop-down that allows the user to select the in-use serial protocol.
![dropdown0](images/proto_dropdown-1.png){: width="60%" }

Offering:
![dropdown1](images/proto_dropdown-0.png){: width="40%" }

### Usage

| Item | Usage |
| ---- | ----- |
| Auto | Auto-detects the protocol from the serial data stream. Note that MPM cannot (yet) be auto-detected reliably, and must be explicitly selected).|
| INAV | INAV protocols, MSP, LTM and MAVLink. Legacy behaviours |
| S-Port | Smartport telemetry, previously required `--smartport` options. Expects a non-inverted stream |
| CRSF | Crossfire Telemetry. |
| MPM | Multi-Protocol-Module telemetry. The output from an EdgeTX / OpenTX radio with a multi-protocol module, FrSky Smartport or Flysky 'AA' via the EdgeTX / OpenTX "Telem Mirror" function. Is not auto-detected, must be explicitly selected. |

#### Notes

* For radar functions (inav-radar, ADSB), it is necessary to set the `--radar-device=`. Leave the protocol selector at 'Auto'.
* For telemetry forwarding, it is necessary to set the `--forward-to=`. Leave the protocol selector at 'Auto'.
* For FlySky MPM telemetry, the inav CLI setting `set ibus_telemetry_type = 0` is required; any other `ibus_telemetry_type` value will not work.

#### Auto-detection

* INAV (MSP, LTM, MAVLink) auto-detection should be reliable (legacy function).
* S-Port and CRSF may be less reliably detected.
* MPM is not auto-detected. This may change if EdgeTX merges an [extant PR](https://github.com/EdgeTX/edgetx/pull/1115)
* It is recommended that for S-Port, CRSF and MPM, the desired protocol is set explicitly (not left at "Auto").
