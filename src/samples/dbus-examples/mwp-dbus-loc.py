#!/usr/bin/python

# Simple python example for mwp dbus

import sys
import dbus
import dbus.mainloop.glib

from gi.repository import GLib

def loc_handler(*args):
    print('sig loc: ', args)

def home_handler(*args):
    print('sig home: ', args)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
try:
    bus = dbus.SessionBus()
    obj = bus.get_object("org.stronnag.mwp", "/org/stronnag/mwp")
    mwp = dbus.Interface(obj, "org.stronnag.mwp")

except dbus.DBusException as e:
        print(str(e))
        sys.exit(255)

home  = mwp.GetHome()
print("Init Home: ", home)
loc  = mwp.GetLocation()
print("Init Vehicle: ", loc)

# Access the update interval property, a bit ugly ....
iface = dbus.Interface(obj, dbus_interface='org.freedesktop.DBus.Properties')
mg = iface.get_dbus_method("Get", dbus_interface=None)
intvl = mg("org.stronnag.mwp", "DbusPosInterval")
print("Pos Update Interval: ", intvl)
# Set example
# ms = iface.get_dbus_method("Set", dbus_interface=None)
# ms("org.stronnag.mwp", "DbusPosInterval", dbus.UInt32(500))

obj.connect_to_signal('LocationChanged', loc_handler)
obj.connect_to_signal('HomeChanged', home_handler)
loop = GLib.MainLoop()
obj.connect_to_signal('Quit', loop.quit)
loop.run()
