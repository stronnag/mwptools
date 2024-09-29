package main

import (
	"log"
	"os"
)

func main() {
	if len(os.Args) != 2 {
		log.Fatal("One file required\n")
	}

	fh, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal("open ", err)
	}
	defer fh.Close()
	ltm := NewLTMParser()
	buf := make([]byte, 64)
	for {
		_, err = fh.Read(buf)
		if err != nil {
			break
		}
		ltm.Parse(buf)
	}
}
