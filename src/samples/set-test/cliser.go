package main

import (
	"fmt"
	"go.bug.st/serial"
	"log"
	"os"
	"strings"
)

func serial_reader(p serial.Port, c0 chan SChan) {
	var sc SChan
	inp := make([]byte, 128)
	outb := make([]byte, 1024)
	for {
		nb, err := p.Read(inp)
		if err == nil && nb > 0 {
			outb = append(outb,inp[0:nb]...)
			// require "# " as prompt
			if nb > 1 && inp[nb-2] == 0x23 && inp[nb-1] == 0x20 {
				sc.len = len(outb)
				sc.data = make([]byte, sc.len)
				copy(sc.data, outb)
				c0 <- sc
				outb = outb[:0]
			}
		} else {
			if err != nil {
				fmt.Fprintf(os.Stderr, "Read error: %s\n", err)
			}
			p.Close()
			return
		}
	}
}

func Serial_write(p serial.Port, buf string) {
	p.Write([]byte(buf))
}

func MSPRunner(name string, c0 chan SChan) serial.Port {
	mode := &serial.Mode{
		BaudRate: 115200,
	}
	var sb strings.Builder
	sb.WriteString("/dev/")
	sb.WriteString(name)

	p, err := serial.Open(sb.String(), mode)

	if err != nil {
		log.Fatal(err)
	}
	go serial_reader(p, c0)
	Serial_write(p, "#")
	return p
}

func MSPClose(p serial.Port) {
	p.Close()
}
