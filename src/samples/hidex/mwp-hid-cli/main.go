package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"os"
	"strings"
)

func main() {
	var addr = "localhost:31025"
	if len(os.Args) == 2 {
		addr = os.Args[1]
	}

	uaddr, err := net.ResolveUDPAddr("udp", addr)
	if err == nil {
		conn, err := net.DialUDP("udp", nil, uaddr)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("udp conn %+v %+v\n", conn.LocalAddr(), conn.RemoteAddr())
		var rep string
		scanner := bufio.NewScanner(os.Stdin)
		for {
			fmt.Print("> ")
			if scanner.Scan() {
				input := scanner.Text()
				conn.Write([]byte(input))
				buf := make([]byte, 128)
				_, _, err := conn.ReadFromUDP(buf)
				if err == nil {
					if buf[0] == 0 {
						rep = "ok"
					} else {
						rep = string(buf)
					}
					fmt.Println(rep)
				} else {
					fmt.Printf("read %+v\n", err)
					break
				}
				if strings.HasPrefix(input, "quit") {
					break
				}
			} else {
				break
			}
		}
	}
}
