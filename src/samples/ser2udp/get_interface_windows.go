package main

import (
	"fmt"
	"net"
)

func Get_interface(name string) {
	//	var res []string
	ifc, err := net.InterfaceByName(name)
	if err == nil {
		addrs, _ := ifc.Addrs()
		for _, a := range addrs {
			switch v := a.(type) {
			case *net.IPAddr:
			case *net.IPNet:
				fmt.Printf("External address: %v\n", v.IP.String())
				//				res = append(res, v.IP.String())
			}
		}
	}
}
