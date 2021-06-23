package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"strings"
	"strconv"
	"time"
	"go.bug.st/serial"
	"encoding/binary"
	"github.com/xo/terminfo"
	"encoding/json"
	"bytes"
)

type JSONu8Slice []uint8
type JSItem struct {
	Stamp    float64     `json:"stamp"`
	Length   uint16      `json:"length"`
	Dirn     byte        `json:"direction"`
	RawBytes JSONu8Slice `json:"rawdata"`
}


/*
 * uncomment for non-standard byte array formatting
func (u JSONu8Slice) MarshalJSON() ([]byte, error) {
	var result string
	if u == nil {
		result = "null"
	} else {
		result = strings.Join(strings.Fields(fmt.Sprintf("%d", u)), ",")
	}
	return []byte(result), nil
}
*/

var (
	_baud   = flag.Int("b", 115200, "Baud rate")
	_device = flag.String("d", "", "Serial Device")
	nometa  = flag.Bool("nometa", false, "No metadata")
	jstream = flag.Bool("js", false, "JSON stream")
)

func check_device() (string, int) {
	var baud int
	ss := strings.Split(*_device, "@")
	name := ss[0]
	if len(ss) > 1 {
		baud, _ = strconv.Atoi(ss[1])
	} else {
		baud = *_baud
	}
	if name == "" {
		for _, v := range []string{"/dev/ttyACM0", "/dev/ttyUSB0"} {
			if _, err := os.Stat(v); err == nil {
				name = v
				baud = *_baud
				break
			}
		}
	}
	if name == "" {
		log.Fatalln("No device given")
	} else {
		log.Printf("Using device %s\n", name)
	}
	return name, baud
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of mwp-serial-cap [options] file\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	adata := flag.Args()
	if len(adata) == 0 {
		log.Fatalln("No output file given\n")
	}

	ti, err := terminfo.LoadFromEnv()
	if err != nil {
		log.Fatal(err)
	}

	file, err := os.Create(adata[0])
	if err != nil {
		log.Fatal(err)
	}

	name, baud := check_device()
	//	fmt.Printf("name %s, baud %d, outfile %s\n", name, baud, outfile)

	defer file.Close()

	if *nometa == false && *jstream == false {
		file.Write([]byte("v2\n"))
	}
	/*
	   * the "meta" binary raw log just writes out 'records' of what has been received
	   * each record being (assume it's a non-ancient log and starts "v2\n"):
	     struct {
	      double time_offset; // seconds
	      ushort data_size; // bytes
	      uchar direction; // 'i' or 'o' (in or out)
	      uchar raw_bytes[data_size]; data fragment read
	    }
	*/

	btdev := false
	var s serial.Port
	var bt *BTConn

	if len(name) == 17 && name[2] == ':' && name[8] == ':' && name[14] == ':' {
		bt = NewBT(name)
		btdev = true
		defer bt.Close()
	} else {
		mode := &serial.Mode{BaudRate: baud}
		s, err = serial.Open(name, mode)
		if err != nil {
			log.Fatal(err)
		}
		if strings.Contains(name, "rfcomm") {
			time.Sleep(2 * time.Second)
		}
	}
	tbuf := new(bytes.Buffer)
	ti.Fprintf(tbuf, terminfo.ClrEol)

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	cbuf := new(bytes.Buffer)
	ti.Fprintf(cbuf, terminfo.CursorInvisible)
	xbuf := new(bytes.Buffer)
	ti.Fprintf(xbuf, terminfo.CursorNormal)
	os.Stdout.Write(cbuf.Bytes())
	defer os.Stdout.Write(xbuf.Bytes())

	go func() {
		var start time.Time
		buf := make([]byte, 1024)
		n := 0
		nb := 0
		for {
			if btdev {
				n, _ = bt.Read(buf)
			} else {
				n, _ = s.Read(buf)
			}
			if n > 0 {
				if start.IsZero() {
					start = time.Now()
				}
				diff := float64(time.Now().Sub(start)) / 1000000000.0
				if *jstream {
					ji := JSItem{diff, uint16(n), 'i', buf[0:n]}
					js, _ := json.Marshal(ji)
					fmt.Fprintln(file, string(js))
				} else {
					if *nometa == false {
						var header = struct {
							offset float64
							size   uint16
							dirn   byte
						}{offset: diff, size: uint16(n), dirn: 'i'}
						binary.Write(file, binary.LittleEndian, header)
					}
					file.Write(buf[0:n])
				}
				nb += n
				fmt.Printf("Read (%d) : %d [%.2fs]", n, nb, diff)
				os.Stdout.Write(tbuf.Bytes())
				os.Stdout.Write([]byte("\r"))
			}
		}
	}()
	<-c
	//	os.Stdout.Write(xbuf.Bytes())
	fmt.Println()
}
