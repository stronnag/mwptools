// +build !windows

package main

import (
	"github.com/xo/terminfo"
	"bytes"
	"os"
	"log"
)

var xbuf *bytes.Buffer
var tbuf *bytes.Buffer

func ti_init() {
	tbuf = new(bytes.Buffer)
	xbuf = new(bytes.Buffer)
	ti, err := terminfo.LoadFromEnv()
	if err == nil {
		cbuf := new(bytes.Buffer)
		ti.Fprintf(cbuf, terminfo.CursorInvisible)
		ti.Fprintf(tbuf, terminfo.ClrEol)
		ti.Fprintf(xbuf, terminfo.CursorNormal)
		os.Stdout.Write(cbuf.Bytes())
	} else {
		log.Printf("Terminfo: %v\n", err)
	}
}

func ti_clreol() {
	os.Stdout.Write(tbuf.Bytes())
}

func ti_cleanup() {
	os.Stdout.Write(xbuf.Bytes())
}
