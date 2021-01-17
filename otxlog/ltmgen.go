package main

import (
	"strings"
	"fmt"
	"encoding/binary"
	"time"
	"math"
	"os"
)

type ltmbuf struct {
	msg []byte
	len byte
}

func newLTM(mtype byte) *ltmbuf {
	paylen := byte(0)
	switch mtype {
	case 'A':
		paylen = 6
	case 'G':
		paylen = 14
	case 'N':
		paylen = 6
	case 'O':
		paylen = 14
	case 'S':
		paylen = 7
	case 'X':
		paylen = 6
	case 'x':
		paylen = 1
	}

	buf := make([]byte, paylen+4)
	buf[0] = '$'
	buf[1] = 'T'
	buf[2] = mtype
	ltm := &ltmbuf{buf, paylen}
	return ltm
}

func (l *ltmbuf) String() string {
	var sb strings.Builder
	for _, s := range l.msg {
		fmt.Fprintf(&sb, "%02x ", s)
	}
	return strings.TrimSpace(sb.String())
}
func (l *ltmbuf) checksum() {
	c := byte(0)
	for _, s := range l.msg[3:] {
		c = c ^ s
	}
	l.msg[l.len+3] = c
}

func (l *ltmbuf) aframe(b OTXrec) {
	binary.LittleEndian.PutUint16(l.msg[3:5], uint16(b.Pitch))
	binary.LittleEndian.PutUint16(l.msg[5:7], uint16(b.Roll))
	binary.LittleEndian.PutUint16(l.msg[7:9], uint16(b.Heading))
	l.checksum()
}

func (l *ltmbuf) gframe(b OTXrec) {
	lat := int32(b.Lat * 1.0e7)
	lon := int32(b.Lon * 1.0e7)
	alt := int32(b.Alt * 100)
	binary.LittleEndian.PutUint32(l.msg[3:7], uint32(lat))
	binary.LittleEndian.PutUint32(l.msg[7:11], uint32(lon))
	l.msg[11] = b.Speed
	binary.LittleEndian.PutUint32(l.msg[12:16], uint32(alt))
	l.msg[16] = b.Fix | (b.Nsats << 2)
	l.checksum()
}

func (l *ltmbuf) oframe(b OTXrec, hlat float64, hlon float64) {
	lat := int32(hlat * 1.0e7)
	lon := int32(hlon * 1.0e7)
	binary.LittleEndian.PutUint32(l.msg[3:7], uint32(lat))
	binary.LittleEndian.PutUint32(l.msg[7:11], uint32(lon))
	binary.LittleEndian.PutUint32(l.msg[11:15], 0)
	l.msg[15] = 1
	l.msg[16] = b.Fix
	l.checksum()
}

func (l *ltmbuf) sframe(b OTXrec) {
	binary.LittleEndian.PutUint16(l.msg[3:5], b.Mvbat)
	binary.LittleEndian.PutUint16(l.msg[5:7], b.Mah)
	l.msg[7] = b.Rssi
	l.msg[8] = b.Aspeed
	l.msg[9] = b.Status
	l.checksum()
}

func (l *ltmbuf) xframe(b OTXrec, xcount uint8) {
	binary.LittleEndian.PutUint16(l.msg[3:5], b.Hdop)
	l.msg[5] = 0
	l.msg[6] = xcount
	l.msg[7] = 0
	l.checksum()
}

func (l *ltmbuf) lxframe() {
	l.msg[3] = 0
	l.checksum()
}

func calc_speed(b OTXrec, tdiff time.Duration, llat, llon float64) uint8 {
	spd := uint8(0)
	if tdiff > 0 && llat != 0 && llon != 0 {
		// Flat earth
		x := math.Abs(to_radians(b.Lon-llon) * math.Cos(to_radians(b.Lat)))
		y := math.Abs(to_radians(b.Lat - llat))
		d := math.Sqrt(x*x+y*y) * 6371009.0
		spd = uint8(d / tdiff.Seconds())
	}
	return spd
}

func LTMGen(s *MSPSerial, seg OTXSegment, verbose bool, fast bool) {

	llat := float64(0)
	llon := float64(0)
	xcount := uint8(0)
	var lt time.Time

	for _, b := range seg.Recs {
		tdiff := b.Ts.Sub(lt)
		if b.Crsf {
			b.Speed = calc_speed(b, tdiff, llat, llon)
			llat = b.Lat
			llon = b.Lon
		}

		l := newLTM('G')
		l.gframe(b)
		s.Write(l.msg)
		if verbose {
			fmt.Fprintf(os.Stderr, "Gframe : %s\n", l)
		}

		l = newLTM('A')
		l.aframe(b)
		s.Write(l.msg)
		if verbose {
			fmt.Fprintf(os.Stderr, "Aframe : %s\n", l)
		}

		l = newLTM('O')
		l.oframe(b, seg.Hlat, seg.Hlon)
		s.Write(l.msg)
		if verbose {
			fmt.Fprintf(os.Stderr, "Oframe : %s\n", l)
		}

		l = newLTM('S')
		l.sframe(b)
		s.Write(l.msg)
		if verbose {
			fmt.Fprintf(os.Stderr, "Sframe : %s\n", l)
		}

		l = newLTM('X')
		l.xframe(b, xcount)
		s.Write(l.msg)
		xcount = (xcount + 1) & 0xff
		if verbose {
			fmt.Fprintf(os.Stderr, "Xframe : %s\n", l)
		}

		if !lt.IsZero() {
			if fast {
				time.Sleep(10 * time.Millisecond)
			} else if tdiff > 0 {
				time.Sleep(tdiff)
			}
		}
		lt = b.Ts
	}
	if s.Klass() == DevClass_FD {
		b := OTXrec{}
		l := newLTM('X')
		l.xframe(b, xcount)
		s.Write(l.msg)
		l = newLTM('x')
		l.lxframe()
		s.Write(l.msg)
	}
	s.Close()
}
