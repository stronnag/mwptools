# `mwp-sql-rebase`

## Introduction

Rebases (sets a new origin, shifting all locations) a mwp SQlite log file, writing a new database.

## Usage

``` shell
$ mwp-sql-rebase --help
Usage:
  mwp-sql-rebase [OPTION?]  newdb

Help Options:
  -h, --help                  Show help options

Application Options:
  -d, --old-db=DATABASE       Extant databse
  --lat=LAT                   Base latitude
  --lon=LON                   Base longitude
  -i, --id=ID (default 1)     Log index
  --verbose                   verbose
```

e.g.

``` shell
$ mwp-sql-rebase --lat 54.163170 --lon -4.739000 -d old-dbfile.db new-dbfile.db
```

## Installing

``` shell
$ make install
```
