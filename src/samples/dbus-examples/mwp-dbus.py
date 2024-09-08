#!/usr/bin/python

# Simple python example for mwp dbus

import sys
import dbus

try:
    bus = dbus.SessionBus()
    mwp = dbus.Interface(bus.get_object("org.stronnag.mwp",
                                    "/org/stronnag/mwp"),
		                    "org.stronnag.mwp")
except dbus.DBusException as e:
        print(str(e))
        sys.exit(255)

device_list = mwp.GetDevices()
for dev in device_list:
    print("    [" + dev + "]")

pts=0
try:
    filename = sys.argv[1]
    pts = mwp.LoadMission(filename)
    print("Loaded " + filename + " with " + str(pts) + " mission points")
except IndexError:
    print("no mission given")

constat = mwp.ConnectionStatus()
if constat[1]:
    print("Connected to "+constat[0])
else:
    print("Not connected")
    constat = mwp.ConnectDevice(device_list[0])

if constat[-1]:
    print("now connected to "+device_list[0])
    if pts > 0:
        nwpts = mwp.UploadMission(True)
        print("Uploaded " + str(nwpts) + " waypoints to the FC")
