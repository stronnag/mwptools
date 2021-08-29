// +build !linux

package main

import (
	"log"
	"errors"
)

type BTConn struct {
	fd int
}

func NewBT(id string) *BTConn {
	log.Fatal("BT sockets are Linux only")
	return &BTConn{-1}
}

func (bt *BTConn) Read(buf []byte) (int, error) {
	return -1, errors.New("Unsupported OS")
}

func (bt *BTConn) Write(buf []byte) (int, error) {
	return -1, errors.New("Unsupported OS")
}
func (bt *BTConn) Close() error {
	return errors.New("Unsupported OS")

}
