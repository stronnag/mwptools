mwptools
========

"A mission planner for the rest of us"

## Overview

mwptools provides a mission planner, real time flight logger and log
replay / blackbox replay functions for the iNav FC firmware.

In addition, mwptools provides a small suite of tools to manage a
MultiWii NAV flight controller and other CleanFlight based FCs. The
suite consists of tools that the author finds useful to manage and
monitor 'in the field' using a low powered Linux based netbook or
chromebook running Arch Linux.

## Tools

 * mwp : "A mission planner for the rest of us". Simple mission planning and monitoring. Mission Planning is provided for iNav and MW-NAV (MW 2.4). Monitoring, logging and recording for iNav, MW and CleanFlight;
 * pidedit : PID editor (MW);
 * switchedit : Transmitter switch editor (MW);
 * mspsim : An MSP (MultiWii Serial Protocol) simulator. Used to develop the other components of the suite;
 * Tools to transform mwp log files to SQL, GPX and KML.

## Platforms and OS

The tools are designed to be portable and as far as possible platform
and architecure agnostic. The suite is developed on Arch Linux and is
tested on Ubuntu (latest and most recent LTS), Fedora (current) and
FreeBSD (current release); building and running on any platform that
supports (recent versions of):

 * gtk+3.0 (3.18 or later);
 * vala and gcc;
 * Clutter (software GL is fine);
 * libchamplain;
 * libespeak;
 * libgdl;
 * mspsim requires Posix pseudo-terminals.

Please see the docs directory for specific development
requirements.

mwptools is tested on x86_64, ia32 and ARM devices.

## Compatibility

As well as supporitng iNav, mwp aims to be compatible with EOSBandi's
WinGUI for MW. It used the same XML mission file format (with mwp
extensions) and aims to provide similar functionaliy where it is
possible to reverse engineer the required protocol formats.

## Licence

GPL v3 or later
