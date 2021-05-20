package main

import (
	"fmt"
	"context"
	"github.com/jochenvg/go-udev"
	"github.com/eiannone/keyboard"
	"go.bug.st/serial"
)

type SChan struct {
	len  uint16
	cmd  uint16
	ok   bool
	data []byte
}

func main() {
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
		sp = MSPRunner(d.Sysname(), c0)
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
					MSPReboot(sp)
				}
			} else if ev.Key == keyboard.KeyCtrlC {
				done = true
			}

		case v := <-c0:
			switch v.cmd {
			case msp_DEBUG:
				fmt.Printf("DBG: %s", string(v.data))
			case msp_REBOOT:
			default:
				fmt.Printf("Unexpected MSP %d %x\n", v.cmd, v.cmd)
			}
		case d := <-ch:
			switch d.Action() {
			case "add":
				fmt.Printf("Add event: /dev/%s\n", d.Sysname())
				sp = MSPRunner(d.Sysname(), c0)
			case "remove":
				fmt.Printf("Remove event: /dev/%s\n", d.Sysname())
			}
		}
	}
}
