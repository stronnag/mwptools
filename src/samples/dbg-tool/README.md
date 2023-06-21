# mwp dbg-tool

## Description

`dbg-tool` is a simple tool to support [INAV](https://github.com/iNavFlight/inav) serial debugging, as described in [the INAV documentation](https://github.com/iNavFlight/inav/blob/master/docs/development/serial_printf_debugging.md). It may be considered to be a much simplified replacement for [@fiam's msp-tool](https://github.com/fiam/msp-tool).

## Features

* Displays inav debug messages in a terminal
* Reboots the FC when 'R' is pressed
* Linux, uses `udev` to discover the serial port.

## Usage

Just run the `dbg-tool`; it will discover any extant plugged USB serial device, or provide the device node. The baudrate defaults to 115200, otherwise it may be specified:

`dbg-tool` may also be used with the INAV SITL by supplying a hostname:port as the parameter.

```
dbg-tool
# or
dbg-tool /dev/cuaU0
# or
dbg-tool COM17
# or (good luck ...)
dbg-tool -baudrate 9600
# (SITL)
dbg-tool localhost:5760
```

For non-discover-able devices (e.g. Bluetooth), the device name must be provided:

```
dbg-tool /dev/rfcomm3
```

On Linux, `udev` is used to recognise device nodes as they are plugged / unplugged.

For non-Linux, the device given on the command line, or the initially discovered device will be re-polled if it is unplugged / plugged.

### Serial port management

* If a device node is provided on the command line, that is used exclusively. On FC reboot, the device node will be polled for reconnection. It is not necessary for the specified device to be present when `dbg-tool` is invoked.
* If no device node is provided, then the outcome is OS dependent.
  - Linux: `udev` events are used to identify connection / disconnection. It is not necessary for the device to be present when `dbg-tool` is invoked.
  - Non-Linux: Serial devices are enumerated at startup. The first device will be used, including across FC reboot. If no suitable device is present at startup, `dbg-tool` will exit.

### Development Cycle

During a typical build / flash / debug cycle, it will be necessary to quit `dbg-tool` in order to flash new firmware to the FC, and then re-invoke `dbg-tool` to see `MSP_DEBUGMSG` messages. If it required to see messages from early in the boot cycle, using `dbg-tool`'s `reboot` key command (`r` / `R`) will maximise the chances of catching message from early in the FC boot process.

## Example output

### FC / VCP Serial

```
[dbg-tool] 15:13:44.806365 Opened /dev/ttyACM0
[dbg-tool] 15:13:45.655200 DBG: [     1.409] Memory allocated. Free memory = 1828
[dbg-tool] 15:13:45.655273 DBG: [     1.409] GYRO CONFIG { 0, 4000 } -> { 0, 4000}; regs 0x00, 0x01
[dbg-tool] 15:13:47.862979 Variant: INAV (3.056592879s)
[dbg-tool] 15:13:47.879039 Version: 7.0.0 (3.072648158s)
[dbg-tool] 15:13:49.110944 DBG: [     4.872] Gyro calibration complete (-16, -12, 0)
[dbg-tool] 15:13:51.111053 DBG: [     6.873] Gravity calibration complete (932)
[dbg-tool] 15:13:51.862906 DBG: [     7.627] Barometer calibration complete (6701)
```

* MSP Processing is available after c. 3 seconds
* The calibration process takes nearly 8 seconds

For the above,the following was specifically set in the CLI:

```
serial 20 32769 115200 115200 0 115200

set log_level = DEBUG
set log_topics = 4294967295
```

### SITL Example

```
[dbg-tool] 16:49:04.597413 Opened localhost:5767
[dbg-tool] 16:49:05.520986 Variant: INAV (923.50912ms)
[dbg-tool] 16:49:05.521202 Version: 7.0.0 (923.729755ms)
[dbg-tool] 16:49:07.521404 DBG: [     3.755] Gyro calibration complete (0, 0, 0)
[dbg-tool] 16:49:09.523056 DBG: [     5.756] Barometer calibration complete (-25)
```

## Restrictions

Only one USB serial device can be active.

## Installing

* Requires a `go` compiler (`golang`)

With GNU make:

```
make
# or
# FreeBSD
gmake
```

Otherwise:

```
# Once ...
go mod tidy
# and then
go build -ldflags "-w -s"
```

Note you can cross compiler for any `golang` supported OS / hardware, via the `GOOS` / `GOARCH` environment variables:

```
# Hosted on Linux
$ GOARCH=riscv64 GOOS=freebsd make clean all
go build -ldflags "-w -s"
$ file dbg-tool
dbg-tool: ELF 64-bit LSB executable, UCB RISC-V, double-float ABI, version 1 (FreeBSD), statically linked, for FreeBSD 12.3, FreeBSD-style, Go BuildID=8p975X5SeLojpAYLxqIr/-S-Ne3CFQuAG0ijuwtue/4aR43vOc4CItWH9zaYb-/P90oWbPuxVpli7o-ba44, stripped
```

```
# Hosted on Linux (even WSL) or Msys2
$ GOARCH=386 GOOS=windows make clean all
go build -ldflags "-w -s"
$ file dbg-tool.exe
dbg-tool.exe: PE32 executable (console) Intel 80386 (stripped to external PDB), for MS Windows, 6 sections
```
