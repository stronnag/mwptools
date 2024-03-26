# Movemission

Simple tools to re-base an INAV/MW XML mission file.

## Usage

```
movemission --help
Usage of movemission --rebase=lat,lon [options] missionfile
  -output string
    	Output file (default "-")
  -rebase string
    	rebase to
```

Relocates the mission file (`missionfile`) to the location defined by `lat,lon`.

* The latitude and longitude must be decimal degrees with a `.` as the decimal separator
* The latitude and longitude are separated by a single comma

If the output file `output` is not defined, `stdout` (the terminal screen) is used.

## Installation

Requires a Go compiler.

```
make
# or (install to ~/.local/bin/)
make install
# or (install to /usr/bin/)
sudo make install prefix=/usr
```

## Operating system support

Any OS for which there is a Go compiler. May be cross compiled using standard Golang variables:

```
GOOS=windows make
GOOS=freebsd GOARCH=riscv64 make
```

## Notes

If the home location metadata is available in the mission file, that will be used as rebase origin, otherwise the first geographic WP is used.
