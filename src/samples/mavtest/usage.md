# Mavlink conformance tester

## Usage

* Validate captured raw data from mavlink telemetry. It is recommended that you use use `mwp-serial-capture` for the data capture, however any raw data capture should do.
  ```
  $ mwp-serial-cap [-b 115200] [-d /dev/ttyACM0] [-other-options] mavraw.bin
  ```

* Analyse the data
  ```
  $ mavtest mavraw.bin
  ```

## Build

```
$ ninja
## or
$ go build mavtest.go
```
