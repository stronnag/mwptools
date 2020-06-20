package main

import (
	"os"
	"fmt"
	"log"
	"flag"
)

func show_size(sz int64) string {
	var s string
	switch {
	case sz > 1024*1024:
		s = fmt.Sprintf("%.2f MB", float64(sz)/(1024*1024))
	case sz > 10*1024:
		s = fmt.Sprintf("%.1f KB", float64(sz)/1024)
	default:
		s = fmt.Sprintf("%d B", sz)
	}
	return s
}

func main() {

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of bbsummary [options] file\n")
		flag.PrintDefaults()
	}

	var dump bool
	var idx int
	flag.IntVar(&idx, "index", 0, "Log index")
	flag.BoolVar(&dump, "dump", false, "Dump headers and exit")
	flag.Parse()

	files := flag.Args()
	if len(files) == 0 {
		flag.Usage()
		os.Exit(1)
	}

	if dump {
		bblreader(files[0], 1, true)
		os.Exit(1)
	}

	for _, fn := range files {
		bmeta, err := GetBBLMeta(fn)
		if err == nil {
			for _, b := range bmeta {
				if (idx == 0 || idx == b.index) && b.size > 4096 {
					fmt.Printf("Log      : %s / %d\n", b.logname, b.index)
					fmt.Printf("Craft    : %s on %s\n", b.craft, b.cdate)
					fmt.Printf("Fireware : %s of %s\n", b.firmware, b.fwdate)
					fmt.Printf("Size     : %s\n", show_size(b.size))
					bblreader(fn, b.index, false)
					fmt.Printf("Disarm   : %s\n\n", b.disarm)
				}
			}
		} else {
			log.Fatal(err)
		}
	}
}
