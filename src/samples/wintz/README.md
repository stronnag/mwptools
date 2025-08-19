## Overview

Windows, in its finest tradition of gratuitous incompatibility with everyone else, uses its own time zone name rather than standard IANA "Olsen" time zone database used elsewhere.

As a result, the "standard" time zone detection code in mwp is unable to provide local timezones for Blackbox files on Windows.

The `wintz` application may be used to determine the local time zone in mwp, by defining the `zone-detect` setting:

```
# Windows
gsettings set org.stronnag.mwp zone-detect 'wintz -xml /path/to/windowsZones.xml --'

# Other OS
gsettings set org.stronnag.mwp zone-detect 'wintz --'
```

For Window, the `-xml` parameter is required. `/path/to/windowsZones.xml` represents to full path of the `windowsZones.xml` file.

* Download the latest [IANA / Olsen database mapping](https://github.com/unicode-org/cldr/blob/main/common/supplemental/windowsZones.xml)

Note the trailing `--` is necessary to prevent the command line parser being confused by southern hemisphere locations.

## Building

```
go mod tidy
go build -ldflags "-w -s"
```

Place the resulting `wintz` / `wintz.exe` somewhere that mwp can find it.

## On POSIX platforms

You can also use `wintz` on POSIX platforms (FreeBSD, Linux, MacOS). If you do not supply the `-xml FILE` parameter, it will return the Olsen name used on these platforms

## Examples

The `wintz`  program uses the online time zone database `https://api.geotimezone.com/public/timezone` to return an IANA / Olsen name for a given location, for example:

```
$ curl -s "https://api.geotimezone.com/public/timezone?latitude=54.35&longitude=-4.52" | jq
{
  "longitude": -4.52,
  "latitude": 54.35,
  "location": "Isle of Man",
  "country_iso": "IM",
  "iana_timezone": "Europe/Isle_of_Man",
  "timezone_abbreviation": "GMT",
  "dst_abbreviation": "BST",
  "offset": "UTC+0",
  "dst_offset": "UTC+1",
  "current_local_datetime": "2025-08-19T18:18:28.506",
  "current_utc_datetime": "2025-08-19T18:18:28.506Z"
}
```

Note that when used by mwp, the latitude and longitude parameters are supplied by mwp from the bounding box of the log file.

### Return Windows time zone name

```
$ wintz -xml windowsZones.xml  -- -38.2363202 175.8948818
New Zealand Standard Time

$ wintz -xml windowsZones.xml -- 44.7996603 8.7620170
W. Europe Standard Time

```

### Return standard IANA / Olsen

``` sh
$ wintz --  -38.2363202 175.8948818
Pacific/Auckland

$ wintz -- 45 9
Europe/Rome
```
