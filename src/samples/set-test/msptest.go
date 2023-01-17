package main

import (
	"context"
	"fmt"
	"github.com/eiannone/keyboard"
	"github.com/jochenvg/go-udev"
	"go.bug.st/serial"
	"os"
	"strconv"
	"time"
)

type SChan struct {
	len  uint16
	cmd  uint16
	ok   bool
	data []byte
}

func main() {
	connected := ""
	init := false
	expect := uint16(0)
	loops := 0

	if len(os.Args) > 1 {
		loops, _ = strconv.Atoi(os.Args[1])
	}

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
		fmt.Printf("Found: /dev/%s (%s, %s)\n", d.Sysname(), d.PropertyValue("ID_VENDOR"),
			d.PropertyValue("ID_MODEL"))
		if d.PropertyValue("ID_VENDOR") == "INAV" && len(connected) == 0 {
			connected = d.Sysname()
			sp = MSPRunner(d.Sysname(), c0, init)
			MSPSetting(sp)
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

	var wstart time.Time
	for done := false; !done; {
		select {
		case ev := <-keysEvents:
			if ev.Err != nil {
				panic(ev.Err)
			}
			if ev.Key == 0 {
				if ev.Rune == 'R' {
					if sp != nil {
						MSPReboot(sp)
					}
				}
			} else if ev.Key == keyboard.KeyCtrlC {
				done = true
			}

		case v := <-c0:
			if !v.ok {
				fmt.Printf("Failed MSP %d %x\n", v.cmd, v.cmd)
				return
			}

			switch v.cmd {
			case msp_COMMON_SETTING:
				nval := uint16(0)
				if init {
					nval = Decode_buffer(v.data)
					fmt.Fprintf(os.Stderr, "Read value = %d (%d)\n", nval, expect)
					if nval != expect {
						done = true
					}
					if loops != 0 && nval == uint16(loops) {
						done = true
					}
					nval += 1
					expect += 1
				} else {
					init = true
					expect = nval
					fmt.Fprintf(os.Stderr, "Initalising ...\n")
				}
				MSPEncodeSetting(sp, nval)

			case msp_COMMON_SET_SETTING:
				fmt.Fprintf(os.Stderr, "Saving ...\n")
				wstart = time.Now()
				MSPSave(sp)

			case msp_EEPROM_WRITE:
				et := time.Since(wstart)
				fmt.Fprintf(os.Stderr, "Save took %s\n", et)
				MSPReboot(sp)
			case msp_REBOOT:
			default:
				fmt.Printf("Unexpected MSP %d %x\n", v.cmd, v.cmd)
			}

		case d := <-ch:
			switch d.Action() {
			case "add":
				fmt.Fprintf(os.Stderr, "Add device: /dev/%s (%s, %s)\n", d.Sysname(), d.PropertyValue("ID_VENDOR"),
					d.PropertyValue("ID_MODEL"))
				if d.PropertyValue("ID_VENDOR") == "INAV" && len(connected) == 0 {
					connected = d.Sysname()
					sp = MSPRunner(d.Sysname(), c0, init)
					MSPSetting(sp)
				}
			case "remove":
				et := time.Since(wstart)
				fmt.Fprintf(os.Stderr, "Remove device: /dev/%s (%s)\n", d.Sysname(), et)
				if d.Sysname() == connected {
					sp = nil
					connected = ""
				}
			}
		}
	}
}
