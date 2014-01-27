mwptools
========

"A mission planner for the rest of us"


## Overview

mwptools is a small suite of tools to manage a MultiWii NAV flight
controller. The suite consists of tools that the author finds useful
to manage and monitor 'in the field' using a low powered Linux based
netbook.

## Tools

 * mwp : "A mission planner for the rest of us". Simple mission planning and monitoring;
 * pidedit : PID editor;
 * mspsim : An MSP (MultiWii Serial Protocol) simulator. Used to develop the other components of the suite.

## Platforms and OS

The tools are designed to be portable and as far as possible platform and architecure agnostic. The suite is developed on Arch Linux and is tested on Ubuntu (current release); building and running on any platform that supports:

 * gtk+3.0 (3.8 or later);
 * vala and gcc;
 * Clutter (software GL is fine);
 * libchamplain;
 * mspsim requires Posix pseudo-terminals. 

mwptools is tested on x86_64, ia32 and ARM devices.

## Build and install

Individual (per-tool) Makefiles (or the top level makeall.sh script). The install phase performs a user install (~/bin/ and .local/share), creating directories. 

On Ubuntu, the current (13.04) libchamplain does not support required bounding box functions. You need to make the 'mwpu' target on Ubuntu (auto-detected by makeall.sh).

## Compatibility

mwp aims to be compatible with EOSBandi's WinGUI. It used the same XML mission file format (with mwp extensions) and aims to provide similar functionaliy where it is possible to reverse engineer the required protocol formats.

## Caveats

The MultiWii NAV protocol is under heavy development and is not  (AFAIK) documented. Additionally, the author has not yet built his GPS / NAV capable quad-copter. mspsim has been used for all NAV related protocol testing, and any errors are likely to have been propogated to both mwp and mspsim. You have been warned.

## Where, when

Here, soon.
