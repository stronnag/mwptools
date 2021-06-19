# Mavlink conformance tester

## Usage

* capture the raw data from mavlink telemetry
  ```
  $ mwp-serial-cap -nometa [-b 115200] [-d /dev/ttyACM0] mavraw.bin
  ```

* Analyse the data
  ```
  $ mavtest mavraw.bin
  ```
