package main

import (
	"context"
	"fmt"
	"github.com/eiannone/keyboard"
	"github.com/jochenvg/go-udev"
	"go.bug.st/serial"
	"os"
	"time"
)

type SChan struct {
	len  uint16
	cmd  uint16
	ok   bool
	data []byte
}

var st time.Time

func main() {

	userdev := ""
	if len(os.Args) > 1 {
		userdev = os.Args[1]
	}

	connected := ""
	var sp serial.Port
	c0 := make(chan SChan)
	u := udev.Udev{}
	m := u.NewMonitorFromNetlink("udev")
	// Add filters to monitor
	m.FilterAddMatchSubsystem("tty")

	e := u.NewEnumerate()
	e.AddMatchSubsystem("tty")
	e.AddMatchProperty("ID_BUS", "usb")

	if userdev == "" {
		var err error
		devices, _ := e.Devices()
		for i := range devices {
			d := devices[i]
			fmt.Printf("Found: /dev/%s\n", d.Sysname())
			if len(connected) == 0 {
				sp, err = MSPRunner("/dev/"+d.Sysname(), c0)
				if err == nil {
					st = time.Now()
					connected = d.Sysname()
				}
			}
		}
	} else {
		var err error
		sp, err = MSPRunner(userdev, c0)
		if err == nil {
			st = time.Now()
			connected = userdev
		}
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, _ := m.DeviceChan(ctx)

	keysEvents, err := keyboard.GetKeys(10)
	if err != nil {
		panic(err)
	}
	defer keyboard.Close()
	ticker := time.NewTicker(5 * time.Second)
	for done := false; !done; {
		select {
		case <-ticker.C:
			if sp == nil && userdev != "" {
				sp, err = MSPRunner(userdev, c0)
				if err == nil {
					st = time.Now()
					connected = userdev
				}
			}

		case ev := <-keysEvents:
			if ev.Err != nil {
				panic(ev.Err)
			}
			if ev.Key == 0 {
				if ev.Rune == 'R' {
					if sp != nil {
						fmt.Println("Rebooting ...")
						MSPReboot(sp)
					}
				}
			} else if ev.Key == keyboard.KeyCtrlC {
				done = true
			}

		case v := <-c0:
			if v.ok {
				switch v.cmd {
				case msp_DEBUG:
					fmt.Printf("DBG: %s", string(v.data))
				case msp_FC_VARIANT:
					var et = time.Since(st)
					fmt.Printf("Variant: %s (%s)\n", string(v.data[0:4]), et)
					MSPVersion(sp)
				case msp_FC_VERSION:
					var et = time.Since(st)
					fmt.Printf("Version: %d.%d.%d (%s)\n", v.data[0], v.data[1], v.data[2], et)
				case msp_REBOOT:
					if userdev != "" && sp != nil {
						MSPClose(sp)
						sp = nil
						connected = ""
					}
				default:
					fmt.Printf("Unexpected MSP %d %x\n", v.cmd, v.cmd)
				}
			} else if v.cmd == 0xffff {
				sp = nil
				connected = ""
			}
		case d := <-ch:
			switch d.Action() {
			case "add":
				fmt.Printf("Add event: /dev/%s\n", d.Sysname())
				if len(connected) == 0 {
					sp, err = MSPRunner("/dev/"+d.Sysname(), c0)
					if err == nil {
						st = time.Now()
						connected = d.Sysname()
					}
				}
			case "remove":
				fmt.Printf("Remove event: /dev/%s\n", d.Sysname())
				if d.Sysname() == connected {
					sp = nil
					connected = ""
				}
			}
		}
	}
}
