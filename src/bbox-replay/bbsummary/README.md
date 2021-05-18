# bbsummary

## Overview

Simple blackbox summary application:

```
$ ./bbsummary --help
Usage of bbsummary [options] file
  -dump
    	Dump headers and exit
  -index int
    	Log index
```

Multiple logs (with multiple indices) may be given.

## Building

Compiled with

```
$ go build
```

or

```
make
```

Not built or installed by default. Obviously cross-platform.
