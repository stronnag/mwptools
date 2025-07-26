## Introduction

Ruby script to convert mwp JSON logs into a SQLite database that can be replayed by mwp's "Interactive log player"

## Dependencies

* ruby
* Ruby "gems"
  - `optparse`
  - `sequel`
  - `yajl`
  - `sqlite3`

The Ruby "gems" may be installed:
* Preferably, using your distro's package manager
* Using ruby's "gem" command

## Usage

```
$ mwplog2sqlite.rb --help
mwplog2sqlite.rb [options] logfile
    -d, --dbfile DBFN
    -v, --verbose
    -?, --help                       Show this message
```

where:
* `logfile` is a mwp JSON log file

if `--dbfile` is not given, the output SQLite database will be created in the current working directory, with the extension `.db`, otherwise it is the path to the required file.

## Examples

``` shell
# Create a SQLite file in /tmp/mbtest.
mwplog2sqlite.rb -d /tmp/mbtest.db  ~/dl/mwp-no-name-2025-07-12_090154.log

# Create a SQLite mwp-no-name-2025-07-12_090154.log in the current directory
mwplog2sqlite.rb -d /tmp/mbtest.db  ~/dl/mwp-no-name-2025-07-12_090154.log
```

## Caveats

* Replaying SQLite file requires mwp later than 25.07.22
* This script will be subsumed into `flightlog2kml` at some stage
