package main

import (
	"fmt"
)

func Listgen(s OTXSegment) {
	for _, b := range s.Recs {
		fmt.Println(b)
	}
}
