package main

import (
	"flag"
	"fmt"
	"go.bug.st/serial"
	"go.bug.st/serial/enumerator"
	"log"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

type SChan struct {
	data []byte
}

type UConn struct {
	conn *net.UDPConn
	addr net.Addr
}

var (
	verbose int
)

func enumerate_ports() string {
	ports, err := enumerator.GetDetailedPortsList()
	if err != nil {
		log.Fatal(err)
	}
	for _, port := range ports {
		if port.Name != "" {
			if port.IsUSB {
				if port.VID == "0483" && port.PID == "5740" {
					return port.Name
				}
			}
		}
	}
	return ""
}

func read_Serial(s serial.Port, c0 chan SChan) {
	inp := make([]byte, 4096)

	for {
		n, err := s.Read(inp)
		var sc SChan
		sc.data = make([]byte, n)
		copy(sc.data, inp[0:n])
		c0 <- sc
		if err != nil {
			return
		}
	}
}

func read_UDP(uc *UConn, c0 chan SChan) {
	inp := make([]byte, 4096)
	for {
		n, addr, _ := uc.conn.ReadFrom(inp)
		var sc SChan
		sc.data = make([]byte, n)
		copy(sc.data, inp[0:n])
		uc.addr = addr
		c0 <- sc
	}
}

func main() {
	var err error
	var udpnam, devnam string
	serok := false

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [options] device [:port]\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
	}

	flag.IntVar(&verbose, "verbose", 0, "verbosity (0:none, 1:open/close, >1:I/O)")

	flag.Parse()
	rest := flag.Args()
	for _, r := range rest {
		if r == "auto" || strings.HasPrefix(r, "COM") || strings.HasPrefix(r, "/dev") {
			devnam = r
		}
		if strings.HasPrefix(r, ":") {
			udpnam = r
		}
	}

	if devnam == "" {
		devnam = "auto"
	}

	if udpnam == "" {
		udpnam = ":17071"
	}

	mode := &serial.Mode{
		BaudRate: 115200,
	}

	Get_interface("vEthernet (WSL)")

	uaddr, err := net.ResolveUDPAddr("udp", udpnam)
	if err != nil {
		log.Fatal(err)
	}

	conn, err := net.ListenUDP("udp", uaddr)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	uconn := &UConn{conn, nil}

	if verbose > 0 {
		log.Printf("Listening on %s\n", udpnam)
	}

	mc0 := make(chan SChan)
	uc0 := make(chan SChan)
	cc := make(chan os.Signal, 1)
	signal.Notify(cc, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		go read_UDP(uconn, uc0)
		for {
			portnam := ""
			if devnam == "auto" {
				portnam = enumerate_ports()
			} else {
				portnam = devnam
			}
			if portnam != "" {
				serdev, err := serial.Open(portnam, mode)
				if err == nil {
					if verbose > 0 {
						log.Printf("Opened %s\n", portnam)
					}
					go read_Serial(serdev, mc0)
					serok = true
				} else {
					serok = false
				}

				for serok {
					select {
					case s := <-mc0:
						if len(s.data) == 0 {
							serok = false
							serdev.Close()
							if verbose > 0 {
								log.Println("Closed serial")
							}
						} else {
							if len(s.data) > 0 {
								if verbose > 1 {
									log.Printf("Write to udp %d: <%s>\n", len(s.data), string(s.data))
								}
								uconn.conn.WriteTo(s.data, uconn.addr)
							}
						}
					case u := <-uc0:
						if len(u.data) == 0 {
							return
						}
						if serok {
							if verbose > 1 {
								log.Printf("Write to serial %d: <%s>\n", len(u.data), string(u.data))
							}
							serdev.Write(u.data)
						}
					}
				}
				time.Sleep(1 * time.Second)
			}
		}
	}()
	<-cc
	log.Fatalln("Terminated")
}
