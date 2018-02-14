#!/usr/bin/python

# Simple python example for mwp dbus

import sys
import dbus

try:
    bus = dbus.SessionBus()
    mwp = dbus.Interface(bus.get_object("org.mwptools.mwp",
                                    "/org/mwptools/mwp"),
		                    "org.mwptools.mwp")
except dbus.DBusException as e:
        print(str(e))
        sys.exit(255)

device_list = mwp.GetDevices()
for dev in device_list:
    print("    [" + dev + "]")

try:
    filename = sys.argv[1]
except IndexError:
    sys.exit(2)

pts = mwp.LoadMission(filename)
print("Loaded " + filename + " with " + str(pts) + " mission points")
