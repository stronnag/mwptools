package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/eiannone/keyboard"
	"github.com/jochenvg/go-udev"
	"go.bug.st/serial"
)

type SChan struct {
	len  int
	ok   bool
	data []byte
}

func main() {
	connected := ""
	step := 0
	init := false
	expect := 0
	loops := 0

	if len(os.Args) > 1 {
		loops, _ = strconv.Atoi(os.Args[1])
	}

	var sp serial.Port
	var wstart time.Time
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
						Serial_write(sp, "exit\n")
					}
				}
			} else if ev.Key == keyboard.KeyCtrlC {
				if sp != nil {
					Serial_write(sp, "exit\n")
				}
				done = true
			}

		case v := <-c0:
			if strings.Contains(string(v.data), "Reboot") {
				et := time.Since(wstart)
				fmt.Fprintf(os.Stderr, "Save took %s\n", et)
			}

			switch step {
			case 0:
				Serial_write(sp, "get nav_rth_home_altitude\n")
				step = 1
			case 1:
				step = 2
				nval := 0
				if init {
					if n := strings.Index(string(v.data), " = "); n != -1 {
						for j := n + 3; ; j++ {
							c := v.data[j]
							if c == 0xd {
								break
							}
							c = c - 48
							nval = nval*10 + int(c)
						}
						fmt.Fprintf(os.Stderr, "Read value = %d (%d)\n", nval, expect)
						if nval != expect {
							Serial_write(sp, "exit\n")
							done = true
						}
						if loops != 0 && nval == loops {
							Serial_write(sp, "exit\n")
							done = true
						}
						nval += 1
						expect += 1
					}
				} else {
					fmt.Fprintf(os.Stderr, "Initalising ...\n")
					init = true
					expect = nval
				}
				str := fmt.Sprintf("set nav_rth_home_altitude = %d\n", nval)
				Serial_write(sp, str)

			case 2:
				fmt.Fprintln(os.Stderr, "Start Save")
				wstart = time.Now()
				Serial_write(sp, "save\n")
				step = 3
			default:
			}

		case d := <-ch:
			switch d.Action() {
			case "add":
				fmt.Fprintf(os.Stderr, "Add device: /dev/%s (%s, %s)\n", d.Sysname(), d.PropertyValue("ID_VENDOR"),
					d.PropertyValue("ID_MODEL"))
				if d.PropertyValue("ID_VENDOR") == "INAV" && len(connected) == 0 {
					connected = d.Sysname()
					sp = MSPRunner(d.Sysname(), c0)
				}
			case "remove":
				et := time.Since(wstart)
				fmt.Fprintf(os.Stderr, "Remove device: /dev/%s (%s)\n", d.Sysname(), et)
				if d.Sysname() == connected {
					sp = nil
					step = 0
					connected = ""
				}
			}
		}
	}
}
