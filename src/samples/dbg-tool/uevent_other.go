//go:build !linux
// +build !linux

package main

import (
	"fmt"
	"go.bug.st/serial/enumerator"
	"os"
	"runtime"
)

func init_udev(uev chan UEvent) (bool, []string) {
	sdevs := []string{}
	ports, _ := enumerator.GetDetailedPortsList()
	for _, port := range ports {
		if port.IsUSB {
			sdevs = append(sdevs, port.Name)
		}
	}
	if runtime.GOOS == "freebsd" && len(sdevs) == 0 {
		for j := 0; j < 10; j++ {
			name := fmt.Sprintf("/dev/cuaU%d", j)
			if _, err := os.Stat(name); err == nil {
				sdevs = append(sdevs, name)
			}
		}
	}
	return false, sdevs
}
