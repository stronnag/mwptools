package main

import (
	"fmt"
	"github.com/chzyer/readline"
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
		rl, err := readline.New("> ")
		if err != nil {
			panic(err)
		}
		defer rl.Close()

		var rep string
		for {
			input, err := rl.Readline()
			if err != nil { // io.EOF
				break
			}
			conn.Write([]byte(input))
			buf := make([]byte, 128)
			_, _, err = conn.ReadFromUDP(buf)
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
		}
	}
}
