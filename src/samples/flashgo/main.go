package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

type SChan struct {
	len  uint16
	cmd  uint16
	ok   bool
	data []byte
}

func esize(v uint32) string {
	s := ""
	if v < 1024 {
		s = fmt.Sprintf("%uB", v)
	} else {
		d := float64(v)
		d /= 1024.0
		if d < 1024 {
			s = fmt.Sprintf("%.1fKB", d)
		} else {
			d /= 1024.0
			s = fmt.Sprintf("%.1fMB", d)
		}
	}
	return s
}

func get_rate(st time.Time, et time.Time, bread uint32) float64 {
	dt := et.Sub(st).Seconds()
	return float64(bread) / dt
}

const CURSORON = "\033[?25h"
const CURSOROFF = "\033[?25l"
const CLEAREOL = "\033[K"

func cleanup() {
	fmt.Printf(CURSORON)
	fmt.Printf("\n")
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] device ...\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	fname := ""
	dname := ""
	erase := false
	xerase := false
	info := false
	test := false

	echeck := false
	fsize := uint32(0)
	used := uint32(0)
	bread := uint32(0)
	efsize := ""

	var wrfh *os.File
	var st time.Time
	var et time.Time

	flag.StringVar(&fname, "file", "", "output file, auto-generated if not defined")
	flag.StringVar(&dname, "dir", "", "output directory (`cwd` if not defined)")
	flag.BoolVar(&erase, "erase", false, "erase after download")
	flag.BoolVar(&xerase, "only-erase", false, "erase only and exit")
	flag.BoolVar(&info, "info", false, "show info and exit")
	flag.BoolVar(&test, "test", false, "download whole flash regardess of usage")

	flag.Parse()
	args := flag.Args()

	var sp *MSPSerial
	port := ""
	c0 := make(chan SChan)

	if len(args) > 0 {
		port = args[0]
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

	for done := false; !done; {
		select {
		case <-cc:
			cleanup()
			done = true
		case v := <-c0:
			switch v.cmd {
			case msp_QUIT:
				done = true
			case msp_FC_VARIANT:
				fmt.Printf("Firmware: %s\n", string(v.data[0:4]))
				switch string(v.data[0:4]) {
				case "INAV":
					sp.MSPVersion()
				default:
					fmt.Printf("Unsupported firmware\n")
					done = true
				}

			case msp_FC_VERSION:
				fmt.Printf("Version: %d.%d.%d\n", v.data[0], v.data[1], v.data[2])
				sp.MSPBBLConfig()

			case msp_BLACKBOX_CONFIG, msp_BLACKBOX_CONFIGv2:
				if v.data[0] == 1 && v.data[1] == 1 { // enabled, sd flash
					if xerase {
						sp.MSPDataFlashErase()
					} else {
						sp.MSPDataFlashSummary()
					}
				} else if v.cmd == msp_BLACKBOX_CONFIGv2 {
					fmt.Printf("No dataflash found\n")
					done = true
				} else {
					sp.MSPBlackboxConfigV2()
				}

			case msp_DATAFLASH_SUMMARY:
				var isready = v.data[0]
				if echeck {
					if isready == 1 {
						fmt.Println("Completed")
						done = true
					} else {
						echeck = true
						go func() {
							time.Sleep(1 * time.Second)
							sp.MSPDataFlashSummary()
						}()
					}
				} else {
					fsize = binary.LittleEndian.Uint32(v.data[5:9])
					used = binary.LittleEndian.Uint32(v.data[9:13])
					if test {
						used = fsize
						fmt.Printf("Entering test mode for %db\n", used)
					}
					pct := 100 * used / fsize
					fmt.Printf("Data flash %d / %d (%d%%)\n", used, fsize, pct)
					if used == 0 || info {
						done = true
					} else {
						efsize = esize(used)
						st = time.Now()
						if fname == "" {
							fname = fmt.Sprintf("bbl_%s.TXT", st.Format("2006-01-02_150405"))
						}
						if dname == "" {
							os.MkdirAll(dname, os.ModePerm)
							fname = filepath.Join(dname, fname)
						}
						var err error
						wrfh, err = os.Create(fname)
						if err != nil {
							fmt.Printf("Failed to open file [%s] %v\n", fname, err)
							done = true
						} else {
							fmt.Printf("Downloading to %s\n", fname)
							req := uint16(4096)
							if used < 4096 {
								req = uint16(used)
							}
							fmt.Printf(CURSOROFF)
							sp.Data_read(0, req)
						}
					}
				}

			case msp_DATAFLASH_READ:
				//newaddr := binary.LittleEndian.Uint32(v.data[0:4])
				dlen := int(v.len - 4)
				wrfh.Write(v.data[4:v.len])
				//				n, err := wrfh.Write([]byte("Test data\n"))
				//fmt.Fprintf(os.Stderr, "Write %v %v %v %v\n", n, dlen, v.len, err)
				bread += uint32(dlen)
				et = time.Now()
				rate := get_rate(st, et, bread)
				remtime := int(float64(used-bread) / rate)
				pct := 100 * bread / used
				var sb strings.Builder
				for i := 0; i < 50; i++ {
					if uint32(i) < pct*50/100 {
						sb.WriteRune(0x2587)
					} else {
						sb.WriteByte(' ')
					}
				}
				fmt.Printf("\r[%s] %s/%s %3d%% %ds%s", sb.String(), esize(bread), efsize, pct, remtime, CLEAREOL)
				rem := used - bread
				if rem > 0 {
					if rem > 4096 {
						rem = 4096
					}
					sp.Data_read(bread, uint16(rem))
				} else {
					wrfh.Close()
					cleanup()
					fmt.Printf("%d bytes in %.1fs, %.1f bytes/s\n", bread, et.Sub(st).Seconds(), rate)

					if erase {
						fmt.Printf("Start erase\n")
						sp.MSPDataFlashErase()
					} else {
						done = true
					}
				}
			case msp_DATAFLASH_ERASE:
				fmt.Printf("Erase in progress ... \n")
				echeck = true
				sp.MSPDataFlashSummary()
			default:
				fmt.Printf("Unexpected MSP %d (0x%x)\n", v.cmd, v.cmd)
			}
		}
	}
}
