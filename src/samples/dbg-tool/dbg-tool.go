package main

import (
	"flag"
	"fmt"
	"github.com/mattn/go-tty"
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
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] [device-node|host:port]\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	log.SetPrefix("[dbg-tool] ")
	log.SetFlags(log.Ltime | log.Lmicroseconds)

	userdev := ""
	baud := 115200
	nopoll := false

	flag.IntVar(&baud, "baudrate", 115200, "Baud rate")
	flag.BoolVar(&nopoll, "no-poll", false, "Don't poll for version / variant")
	flag.Parse()
	if len(flag.Args()) > 0 {
		userdev = flag.Arg(0)
	}

	connected := ""
	var sp *MSPSerial
	c0 := make(chan SChan)
	uevt := make(chan UEvent)
	have_udev, devlist := init_udev(uevt)
	if userdev == "" {
		if len(devlist) > 0 {
			var err error
			sp, err = MSPRunner(devlist[0], baud, nopoll, c0)
			if err == nil {
				st = time.Now()
				connected = devlist[0]
				if !have_udev {
					userdev = devlist[0]
				}
			}
		} else {
			if !have_udev {
				log.Fatal("No device given or found\n")
				return
			}
		}
	} else {
		var err error
		sp, err = MSPRunner(userdev, baud, nopoll, c0)
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

	ticker := time.NewTicker(1 * time.Second)
	for done := false; !done; {
		select {
		case <-ticker.C:
			if sp == nil && userdev != "" {
				sp, err = MSPRunner(userdev, baud, nopoll, c0)
				if err == nil {
					st = time.Now()
					connected = userdev
				}
			}

		case ev := <-kbchan:
			switch ev {
			case 'R', 'r':
				if sp != nil {
					log.Println("Rebooting ...")
					sp.MSPReboot()
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
					s := v.data[:v.len-1] // remove trailing NUL
					log.Printf("DBG: %s", s)
				case msp_FC_VARIANT:
					var et = time.Since(st)
					log.Printf("Variant: %s (%s)\n", string(v.data[0:4]), et)
					sp.MSPVersion()
				case msp_FC_VERSION:
					var et = time.Since(st)
					log.Printf("Version: %d.%d.%d (%s)\n", v.data[0], v.data[1], v.data[2], et)
				case msp_REBOOT:
					if userdev != "" && sp != nil {
						sp.MSPClose()
						sp = nil
						connected = ""
					}
				default:
					log.Printf("Unexpected MSP %d %x\n", v.cmd, v.cmd)
				}
			} else if v.cmd == 0xffff {
				sp = nil
				connected = ""
			}
		case d := <-uevt:
			switch d.action {
			case "add":
				log.Printf("Add event: %s\n", d.name)
				if len(connected) == 0 {
					sp, err = MSPRunner(d.name, baud, nopoll, c0)
					if err == nil {
						st = time.Now()
						connected = d.name
					} else {
						log.Printf("Connect error %v", err)
					}
				}
			case "remove":
				log.Printf("Remove event: %s\n", d.name)
				if d.name == connected {
					sp = nil
					connected = ""
				}
			}
		}
	}
}
