package main

import (
	"compress/gzip"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

func get_uri(fname string) string {
	return fmt.Sprintf("https://s3.amazonaws.com/elevation-tiles-prod/skadi/%s/%s", fname[0:3], fname)
}

func download(fname, dir string) {
	gzname := fname + ".gz"
	uri := get_uri(gzname)
	gzname = filepath.Join(dir, gzname)

	file, err := os.Create(gzname)
	if err != nil {
		log.Fatal(err)
	}
	client := http.Client{
		CheckRedirect: func(r *http.Request, via []*http.Request) error {
			r.URL.Opaque = r.URL.Path
			return nil
		},
	}
	resp, err := client.Get(uri)
	if err != nil {
		log.Fatal(err)
	}

	_, err = io.Copy(file, resp.Body)
	resp.Body.Close()
	file.Close()
	if err == nil {
		unpack(gzname)
	}
}

func unpack(fname string) {
	gzfh, err := os.Open(fname)
	if err != nil {
		return
	}
	defer gzfh.Close()
	gzrd, err := gzip.NewReader(gzfh)
	defer gzrd.Close()
	n := len(fname) - 3
	ofname := fname[:n]
	outfh, err := os.Create(ofname)
	if err != nil {
		return
	}
	defer outfh.Close()
	_, err = io.Copy(outfh, gzrd)
	if err == nil {
		os.Remove(fname)
	}
}
