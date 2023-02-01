# Exploratory / Test file for CRSF Telemetry

## Introduction

This small project illustrates an effort to understand the CRSF telemetry protocol.
The protocol is actually quite simple.

## CRSF

### Detection

CSRF data consists of frames describing a data item (GPS, BATTERY etc.). Auto-detection is problematic. Looking for `0xea` and applying heuristics over the frame seems like the best bet.

### Frame Format

The following illustrations are from ELRS:

```
CRSF frame has the structure:
<Device address> <Frame length> <Type> <Payload> <CRC>
Device address: (uint8)
Frame length:   length in  bytes including Type (uint8), payload and CRC
Type:           (uint8)
CRC:            (uint8), crc of <Type> and <Payload>
```

* The device address should be `RADIO_ADDRESS`, i.e. `0xea`.
* The CRC is calculated over Type and Payload using the `crc8_dvb_s2` algorithm (as used by inav's MSPv2).
* Within the payload, the data is **big endian**.

#### GPS id=0x02

```
int32     Latitude (degree * 1e7)
int32     Longitude (degree * 1e7)
uint16    Groundspeed (km/h * 10)
uint16    GPS heading (degree * 100)
uint16    Altitude (metre -1000m offset)
uint8     Satellites in use
```

#### VARIO id=0x07

```
int16      Vertical speed (cm/s)
```
#### Battery id=0x08

```
uint16    Voltage (mV * 100)
uint16    Current (mA * 100)
uint24    Used (mAh) ... yes, 3 bytes
uint8     Battery remaining (percent)
```

#### Link Statistics id=0x14

```
uint8     Uplink RSSI Ant. 1 (dBm * -1)
uint8     Uplink RSSI Ant. 2 (dBm * -1)
uint8     Uplink Package success rate / Link quality (%)
int8      Uplink SNR (db)
uint8     Diversity active antenna (enum ant. 1 = 0, ant. 2)
uint8     RF Mode (enum 4fps = 0 , 50fps, 150hz)
uint8     Uplink TX Power (enum 0mW = 0, 10mW, 25 mW, 100 mW, 500 mW, 1000 mW, 2000mW)
uint8     Downlink RSSI (dBm * -1)
uint8     Downlink package success rate / Link quality (%)
int8      Downlink SNR (db)
```

Uplink is the connection from the TX to the vehicle, downlink from the vehicle to TX.

#### Attitude id=0x1e

```
int16_t     Pitch angle (radians * 10000)
int16_t     Roll angle (radians * 10000)
int16_t     Yaw angle (radians *10000)
```

#### Flight Mode id=0x21

```
char[]      Flight mode (NUL terminated string)
```

#### Device Info id=0x29

```
uint8     Destination
uint8     Origin
char[]    Device Name (NUL terminated string)
uint32    NUL Bytes
uint32    NUL Bytes
uint32    NULL Bytes
uint8     255 (Max MSP Parameter (inav))
uint8     0x01 (aPrameter version 1)
```

## Credits

Thanks to the ExpressLRS and INAV projects for the necessary clues. See also the [ELRS Wiki](https://github.com/ExpressLRS/ExpressLRS/wiki/CRSF-Protocol).

## Tools

### Replay

To replay a capture file into mwp:

* Start mwp using a UDP port (40042 is a random port number)
```
  mwp -d udp://:40042 -a
```
* Start the mwp log replay tool, using the same port number:
```
  # Note we must also specific the target host here (localhost)
  mwp-log-replay -d udp://localhost:40042 crsf_raw.log
```

### Dump Data

First, build the `crsfparsert` tool (having installed a rust compiler).

```
cargo build --release
# or (install to ~/.local/bin):
cargo install --path . --root ~/.local/ --force
```
then

```
$ target/release/crsfparser FILE_NAME
```

cross-compilation ...

```
# e.g. build for Windows on Linux
cargo build --release --target x86_64-pc-windows-gnu
```



or install it:

```
# default ~/.cargo/bin
cargo install --path .
```

```
# user preference r.g. ~/.local/bin
cargo install --path . --root ~/.local [--force]
```

The decoded file is dumped to the terminal, formatted (for example, location obfuscated).

```
  93.62s: FM: MANU
  93.76s: VARIO 167 cm/s
  93.81s: ATTI: p -6.20 r 2.80 y 158.10
  93.81s: LINKSTATS: rssi1 49 rssi2 49 UpLQ 100 UpSNR 47 ActAnt 248 Mode 150hz TXPwr 2000mW DnRSSI 59 DnLQ 97 DnSNR 40
  93.84s: RADIO: rate 6666us offset 81us
  93.87s: GPS: dd.dddddd ddd.dddddd 49m 11.5m/s 353.9° 10 sats
```

The log file may be a raw capture (no metadata), or a mwp serial raw log with metadata / record chunking ("v2") or a JSON encoded mwp serial log. See the [mwp-serial-log](../mwp-serial-log/) documentation for more detail.
