# Simple `mwp-hid-server` CLI tool

``` sh
go mod tidy
go build -ldflags "-w -s"
```

Cross compile for other OS:

``` sh
GOOS=windows go build -ldflags "-w -s"
```

Send commands to `mwp-hid-server`.

* Supports readline style recall and editing
* ^D to quit
