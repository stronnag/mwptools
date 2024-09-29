#!/usr/bin/ruby

require 'dbus'


# Create bus and service object
bus = DBus::SessionBus.instance
service = bus.service("org.stronnag.mwp")
mwp = service.object("/org/stronnag/mwp")

# Test if it's up.
# Rather than abort, we could start an instance of mwp if appropriate
#
begin
  pif = mwp["org.freedesktop.DBus.Peer"]
  pif.Ping
rescue
  abort "Service unavailable"
end

# Set the default interface
mwp.default_iface = "org.stronnag.mwp"

# Get the devices known to mwp
devs = mwp.GetDevices
devstr = devs[0].join(", ")
puts "Devices #{devstr}"

# See if we're connected to th FC, for the Connect* methods, the final
# item in the returned array is the connection status. For
# consistency, we can therefore test constat[-1]

constat = mwp.ConnectionStatus
if constat[-1]
  puts "Connected to #{constat[1]}"
else
  puts "Not connected, trying first device ... #{devs[0][0]}"
  constat = mwp.ConnectDevice(devs[0][0])
  puts "Connected state now #{constat[-1]}"
end

# If a mission file was given load it and upload to the FC
if ARGV[0] and File.exist?(ARGV[0])
  npts = mwp.LoadMission ARGV[0]
  puts "Loaded mission from #{ARGV[0]}, #{npts[0]} mission points"
  if constat[-1]
    nwpts = mwp.UploadMission true
    puts "Uploaded #{nwpts[0]} waypoints to the FC"
  end
end

# dump out the interface definitions
#puts mwp.introspect
