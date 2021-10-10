# ser2udp - simple serial to IP (UDP) bridge

`ser2udp` is a simple serial to UDP bridge. It is intended to be used for accessing a serial USB flight controller using Windows 11 / WSLg and mwp; however there is almost nothing either Windows or mwp specific. It can be used as a generic bridge.

## Usage

```
$ ser2udp --help
Usage of ser2udp [options] device [:port]
  -verbose int
    	verbosity (0:none, 1:open/close, >1:I/O)
```

If port is not provided, it defaults to `:17071` (the colon in required).

If device is not provided (which implied port is not either), or is 'auto' then the device will be auto-detected (and has to be (a) USB and (b) have a USB vid:pid of 0483:5740, i.e. a STM32 device).

If `ser2udp` is run in Windows as a bridge for mwp in WSLg, then it will also tell you the addresses of the Linux side interface.

```
> ./set2udp.exe
External address: fe80::1439:d6de:efcb:97e1%17
External address: 172.29.32.1
```

In this case, for mwp use a device name of `udp://172.29.32.1:17071` on the Linux side.

### Verbosity

If verbosity is > 0, then additional debug messages will be displayed:

| Verbosity | Affect |
| --------- | ------ |
| 0         | No debug |
| 1         | Open and close of serial device |
| > 1       | as 1, plus serial / network writes |
