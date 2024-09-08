module mwptools

go 1.19

require (
	go.bug.st/serial v1.6.1
	golang.org/x/sys v0.13.0
)

require geo v1.0.0

require github.com/creack/goselect v0.1.2 // indirect

replace geo v1.0.0 => ./pkg/geo
