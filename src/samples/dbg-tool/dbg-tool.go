package main

import (
	"fmt"
	"github.com/mattn/go-tty"
	"go.bug.st/serial"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type SChan struct {
	len  uint16
	cmd  uint16
	ok   bool
	data []byte
}

type UEvent struct {
	action string
	name   string
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
	uevt := make(chan UEvent)
	have_udev, devlist := init_udev(uevt)
	if userdev == "" {
		if len(devlist) > 0 {
			var err error
			sp, err = MSPRunner(devlist[0], c0)
			if err == nil {
				st = time.Now()
				connected = devlist[0]
				if !have_udev {
					userdev = devlist[0]
				}
			}
		} else {
			if !have_udev {
				fmt.Fprintf(os.Stderr, "No device given or found\n")
				return
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

	cc := make(chan os.Signal, 1)
	signal.Notify(cc, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	tty, err := tty.Open()
	if err != nil {
		log.Fatal(err)

	}
	defer tty.Close()

	kbchan := make(chan rune)
	go func() {
		for {
			r, err := tty.ReadRune()
			if err != nil {
				log.Fatal(err)
			}
			kbchan <- r
		}
	}()

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

		case ev := <-kbchan:
			switch ev {
			case 'R', 'r':
				if sp != nil {
					fmt.Println("Rebooting ...")
					MSPReboot(sp)
				}
			case 'Q', 'q':
				done = true
			}
		case <-cc:
			done = true
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
		case d := <-uevt:
			switch d.action {
			case "add":
				fmt.Printf("Add event: %s\n", d.name)
				if len(connected) == 0 {
					sp, err = MSPRunner(d.name, c0)
					if err == nil {
						st = time.Now()
						connected = d.name
					} else {
						fmt.Printf("Connect error %v", err)
					}
				}
			case "remove":
				fmt.Printf("Remove event: %s\n", d.name)
				if d.name == connected {
					sp = nil
					connected = ""
				}
			}
		}
	}
}
