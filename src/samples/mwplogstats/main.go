package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
)

type Header struct {
	Offset float64
	Size   uint16
	Dirn   byte
}

type MWPLog struct {
	fh   *os.File
	last float64
}

type HexArray []byte

func (h HexArray) String() string {
	var b strings.Builder
	b.WriteString("[")
	for n, v := range h {
		fmt.Fprintf(&b, "0x%02x", v)
		if n != len(h)-1 {
			b.WriteString(", ")
		}
	}
	b.WriteString("]")
	return b.String()
}

func (l *MWPLog) readlog() (Header, HexArray, error) {
	var err error
	var buf []byte

	hdr := Header{}
	err = binary.Read(l.fh, binary.LittleEndian, &hdr)
	if err == nil {
		l.last = hdr.Offset
		buf = make([]byte, hdr.Size)
		l.fh.Read(buf)
		return hdr, buf, err
	}
	return hdr, nil, err
}

func (l *MWPLog) checkvers() bool {
	sig := make([]byte, 7)
	_, err := l.fh.Read(sig)
	if err == nil {
		if string(sig)[0:3] == "v2\n" {
			l.fh.Seek(3, 0)
			return true
		}
	}
	return false
}

func main() {
	var mspfh io.WriteCloser
	var metafh io.WriteCloser
	mspfile := "-"
	metafile := "-"

	flag.StringVar(&mspfile, "msp", "-", "msp output file name ('-' => stderr)")
	flag.StringVar(&metafile, "meta", "-", "metadata output file name ('-' => stdout)")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: mwplogstats [options] logfile\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	nargs := len(flag.Args())
	if nargs != 1 {
		log.Fatal("need a log file\n")
	}

	fh, err := os.Open(flag.Args()[0])
	if err != nil {
		log.Fatal("open ", err)
	}

	if len(mspfile) == 0 || mspfile == "-" {
		mspfh = os.Stderr
	} else {
		mspfh, err = os.Create(mspfile)
		if err != nil {
			log.Fatalf("create %s: %v\n", mspfile, err)
		}
		defer mspfh.Close()
	}
	if len(metafile) == 0 || metafile == "-" {
		metafh = os.Stdout
	} else {
		metafh, err = os.Create(metafile)
		if err != nil {
			log.Fatalf("create %s: %v\n", metafile, err)
		}
		defer metafh.Close()
	}

	logf := MWPLog{}
	logf.fh = fh
	defer logf.fh.Close()

	if !logf.checkvers() {
		log.Fatalln("Check format")
	}

	n := 0
	last := 0.0
	nb := 0
	for {
		hdr, buf, err := logf.readlog()
		if err == nil {
			n += 1
			last = hdr.Offset
			nb += int(hdr.Size)
			dbyte := '<'
			if hdr.Dirn == 'i' {
				dbyte = '>'
			}
			fmt.Fprintf(metafh, "Offset: %.3f dirn: %c size: %d %s\n", hdr.Offset, dbyte, hdr.Size, buf)
			msp_parse(mspfh, buf, hdr.Offset)
		} else if err == io.EOF {
			break
		} else {
			log.Fatal(err)
		}
	}
	mrate := float64(n) / last
	brate := float64(nb) / last

	fmt.Printf("%d items %d bytes %.2f secs, %.2f msg/sec, %.2f byte/sec\n", n, nb, last, mrate, brate)
}
