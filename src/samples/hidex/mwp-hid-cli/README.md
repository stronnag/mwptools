``` sh
go build -ldflags "-w -s"
```

Cross compile for other OS:

``` sh
GOOS=windows go build -ldflags "-w -s"
```
