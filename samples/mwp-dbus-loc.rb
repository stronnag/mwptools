#!/usr/bin/ruby

### gem install ruby-dbus
require 'dbus'

# Create bus and service object
bus = DBus::SessionBus.instance
service = bus.service("org.mwptools.mwp")
mwp = service.object("/org/mwptools/mwp")

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
mwp.default_iface = "org.mwptools.mwp"

# and explicity for properties
mwpi = mwp["org.mwptools.mwp"]

# dump out the interface definitions
puts mwp.introspect

state_name = mwp.GetStateNames[0]
puts "Available states #{state_name.inspect}\n"

state = mwp.GetState[0]
puts "Inital state #{state_name[state]}"
home = mwpi.GetHome
puts "Init Home: #{home.join(' ')}"
loc= mwp.GetLocation
puts "Init Location: #{loc.join(' ')}"
sats= mwp.GetSats
puts "Init Sats: #{sats.join(' ')}"

intvl = mwpi["DbusPosInterval"]
print "Update Intvl #{intvl}\n"

if ARGV.length == 1
  nintvl = ARGV[0].to_i
  mwpi["DbusPosInterval"] = DBus.variant("u", nintvl)
  intvl = mwpi["DbusPosInterval"]
  puts "Updated Intvl = #{intvl}"
end

mwp.on_signal("HomeChanged") do |lat,lon,alt|
  puts "Home changed: #{[lat,lon,alt].join(' ')}"
end

mwp.on_signal("LocationChanged") do |lat,lon,alt|
  puts "Vehicle changed: #{[lat,lon,alt].join(' ')}"
end

mwp.on_signal("SatsChanged") do |sats,fix|
  puts "Sats changed: #{[sats,fix].join(' ')}"
end

mwp.on_signal("StateChanged") do |state|
  puts "State Changed: #{state_name[state]}"
end

loop = DBus::Main.new
mwp.on_signal("Quit") { loop.quit }
loop << bus
loop.run
