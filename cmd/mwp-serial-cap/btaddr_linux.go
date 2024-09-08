package main

import (
	"strconv"
	"strings"
	"syscall"
	"log"
	"golang.org/x/sys/unix"
)

type BTConn struct {
	fd int
}

func str2ba(addr string) [6]byte {
	a := strings.Split(addr, ":")
	var b [6]byte
	for i, tmp := range a {
		u, _ := strconv.ParseUint(tmp, 16, 8)
		b[len(b)-1-i] = byte(u)
	}
	return b
}

func check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func NewBT(id string) *BTConn {
	mac := str2ba(id)
	bt := &BTConn{fd: -1}
	fd, err := unix.Socket(syscall.AF_BLUETOOTH, syscall.SOCK_STREAM, unix.BTPROTO_RFCOMM)
	check(err)
	bt.fd = fd
	addr := &unix.SockaddrRFCOMM{Addr: mac, Channel: 1}
	err = unix.Connect(bt.fd, addr)
	check(err)
	return bt
}

func (bt *BTConn) Read(buf []byte) (int, error) {
	n, err := unix.Read(bt.fd, buf)
	return n, err
}

func (bt *BTConn) Write(buf []byte) (int, error) {
	n, err := unix.Write(bt.fd, buf)
	return n, err
}

func (bt *BTConn) Close() error {
	unix.Close(bt.fd)
	return nil
}

/**
func main() {
	var id string
	if len(os.Args) > 1 {
		id = os.Args[1]
	} else {
		log.Fatal("no device given")
	}
	fd := Connect_bt(id)
	defer Close_bt(fd)

	var buf = make([]byte, 128)
	for {
		n, err := Read_bt(fd, buf)
		check(err)
		if n > 0 {
			fmt.Printf("Received: %v\n", string(buf[0:n]))
		}
	}
}
**/
