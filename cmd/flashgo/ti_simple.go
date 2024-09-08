package main

import "os"

const CURSORON = "\033[?25h"
const CURSOROFF = "\033[?25l"
const CLEAREOL = "\033[K"

func ti_init() {
	os.Stdout.Write([]byte(CURSOROFF))
}

func ti_clreol() {
	os.Stdout.Write([]byte(CLEAREOL))
}

func ti_cleanup() {
	os.Stdout.Write([]byte(CURSORON))
}
