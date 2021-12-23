package main

import (
	"fmt"
	"context"
	"github.com/jochenvg/go-udev"
	"github.com/eiannone/keyboard"
	"go.bug.st/serial"
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
	devices, _ := e.Devices()
	for i := range devices {
		d := devices[i]
		fmt.Printf("Found: /dev/%s\n", d.Sysname())
		if len(connected) == 0 {
			st = time.Now()
			connected = d.Sysname()
			sp = MSPRunner(d.Sysname(), c0)
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

	for done := false; !done; {
		select {
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
			switch v.cmd {
			case msp_DEBUG:
				fmt.Printf("DBG: %s", string(v.data))
			case msp_FC_VERSION:
				var et = time.Since(st)
				fmt.Printf("Version %d.%d.%d (%s)\n", v.data[0], v.data[1], v.data[2], et)
			case msp_REBOOT:
			default:
				fmt.Printf("Unexpected MSP %d %x\n", v.cmd, v.cmd)
			}
		case d := <-ch:
			switch d.Action() {
			case "add":
				fmt.Printf("Add event: /dev/%s\n", d.Sysname())
				if len(connected) == 0 {
					st = time.Now()
					connected = d.Sysname()
					sp = MSPRunner(d.Sysname(), c0)
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
