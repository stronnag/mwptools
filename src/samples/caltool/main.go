package main

import (
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

var st time.Time

func main() {
	var sp *MSPSerial
	acx := 0
	port := ""
	c0 := make(chan SChan)

	if len(os.Args) > 1 {
		port = os.Args[1]
	} else {
		port = Enumerate_ports()
	}
	if port != "" {
		st = time.Now()
		fmt.Printf("Using %s\n", port)
		sp = NewMSPSerial(port)
		sp.Init(c0)
	} else {
		log.Fatalln("No serial device given or detected")
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

	for done := false; !done; {
		select {
		case ev := <-kbchan:
			switch ev {
			case 'R', 'r':
				fmt.Println("Rebooting ...")
				sp.MSPReboot()
			case 'V', 'v':
				sp.MSPCalData()
			case 'A', 'a':
				sp.MSPCalAxis()
			case 'M', 'm':
				sp.MSPCalMag()
			case 'Q', 'q':
				done = true
			}

		case <-cc:
			done = true

		case v := <-c0:
			switch v.cmd {
			case msp_QUIT:
				done = true
			case msp_DEBUG:
				fmt.Printf("DBG: %s", string(v.data))
			case msp_FC_VARIANT:
				var et = time.Since(st)
				fmt.Printf("Variant: %s (%s)\n", string(v.data[0:4]), et)
				sp.MSPVersion()
			case msp_FC_VERSION:
				var et = time.Since(st)
				fmt.Printf("Version: %d.%d.%d (%s)\n", v.data[0], v.data[1], v.data[2], et)
				fmt.Println("Press A to start ACC calibration, M to calibarate MAG, R to reboot, Q to quit")
			case msp_CALIBRATION_DATA:
				cal := DeserialiseCal(v.data)
				fmt.Println("cal data:")
				fmt.Printf("\tacczero_x: %d\n", cal[0])
				fmt.Printf("\tacczero_y: %d\n", cal[1])
				fmt.Printf("\tacczero_z: %d\n", cal[2])
				fmt.Printf("\taccgain_x: %d\n", cal[3])
				fmt.Printf("\taccgain_y: %d\n", cal[4])
				fmt.Printf("\taccgain_z: %d\n", cal[5])
				fmt.Printf("\tmagzero_x: %d\n", cal[6])
				fmt.Printf("\tmagzero_y: %d\n", cal[7])
				fmt.Printf("\tmagzero_z: %d\n", cal[8])
				if len(cal) > 9 {
					// 9 => opflow
					fmt.Printf("\tmaggain_x: %d\n", cal[10])
					fmt.Printf("\tmaggain_y: %d\n", cal[11])
					fmt.Printf("\tmaggain_z: %d\n", cal[12])
				}
			case msp_ACC_CALIBRATION:
				acx += 1
				fmt.Printf("Done axis %d (%d, %v), ", acx, v.len, v.ok)
				if acx == 6 {
					time.Sleep(1000 * time.Millisecond)
					sp.MSPCalData()
					acx = 0
				} else {
					fmt.Println("press A when ready for next")
				}

			case msp_MAG_CALIBRATION:
				fmt.Println("Mag calibration in progress ... await FC beeps")

			case msp_REBOOT:
				return
			default:
				fmt.Printf("Unexpected MSP %d (0x%x)\n", v.cmd, v.cmd)
			}
		}
	}
}
