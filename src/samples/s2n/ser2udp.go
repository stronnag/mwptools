package main

import (
	"go.bug.st/serial"
	"log"
	"net"
	"os"
	"time"
)

type SChan struct {
	data []byte
}
type UChan struct {
	data []byte
	addr net.Addr
}

var uconn *net.UDPConn
var serdev serial.Port

func Read_Serial(c0 chan SChan) {
	inp := make([]byte, 4096)

	for {
		n, err := serdev.Read(inp)
		var sc SChan
		sc.data = make([]byte,n)
		copy(sc.data, inp[:n])
		c0 <- sc
		if err != nil {
			return
		}
	}
}

func Read_UDP(c0 chan UChan) {
	inp := make([]byte, 4096)
	for {
		n, addr, _ := uconn.ReadFrom(inp)
		var sc UChan
		sc.data = make([]byte,n)
		copy(sc.data, inp[:n])
		sc.addr = addr
		c0 <- sc
	}
}

func main() {
	var err error
	var udpnam, devnam string
	serok := false

	switch len(os.Args) {
	case 3:
		udpnam = os.Args[2]
		fallthrough
	case 2:
		devnam = os.Args[1]
	default:
		log.Fatal("ser2net serial_device [udp addr]")
	}

	if udpnam == "" {
		udpnam = ":17071"
	}

	mode := &serial.Mode{
		BaudRate: 115200,
	}

	uaddr, err := net.ResolveUDPAddr("udp", udpnam)
	if err != nil {
		log.Fatal(err)
	}
	uconn, err = net.ListenUDP("udp", uaddr)
	if err != nil {
		log.Fatal(err)
	}
	defer uconn.Close()

	mc0 := make(chan SChan)
	uc0 := make(chan UChan)

	var ua net.Addr
	go Read_UDP(uc0)

	for {
		serdev, err = serial.Open(devnam, mode)
		if err == nil {
			go Read_Serial(mc0)
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
				}
				if ua != nil {
					uconn.WriteTo(s.data, ua)
				}
			case u := <-uc0:
				if len(u.data) == 0 {
					return
				}
				ua = u.addr
				if serok {
					serdev.Write(u.data)
				}
			}
		}
		//		log.Println("Waiting to retry")
		time.Sleep(1 * time.Second)
	}
}
