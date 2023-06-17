//go:build linux

package main

import (
	"context"
	"github.com/jochenvg/go-udev"
)

func check_events(uev chan UEvent) {
	u := udev.Udev{}
	m := u.NewMonitorFromNetlink("udev")
	m.FilterAddMatchSubsystem("tty")
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, _ := m.DeviceChan(ctx)

	for done := false; !done; {
		select {
		case d := <-ch:
			uev <- UEvent{action: d.Action(), name: "/dev/" + d.Sysname()}
		}
	}
}

func init_udev(uev chan UEvent) (bool, []string) {
	var devs []string
	u := udev.Udev{}
	e := u.NewEnumerate()
	e.AddMatchSubsystem("tty")
	e.AddMatchProperty("ID_BUS", "usb")
	devices, _ := e.Devices()
	for i := range devices {
		d := devices[i]
		devs = append(devs, "/dev/"+d.Sysname())
	}
	go check_events(uev)
	return true, devs
}
