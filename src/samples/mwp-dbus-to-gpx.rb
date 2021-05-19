#!/usr/bin/ruby

### gem install ruby-dbus
require 'dbus'
require 'nokogiri'

# Create bus and service object
bus = DBus::SessionBus.instance
service = bus.service("org.mwptools.mwp")
mwp = service.object("/org/mwptools/mwp")

# Test if it's up.
# Rather than abort, we could start an instance of mwp if appropriate
# or sleep / wait for the interface to appear

begin
  pif = mwp["org.freedesktop.DBus.Peer"]
  pif.Ping
rescue
  abort "Service unavailable"
end

# Set the default interface
mwp.default_iface = "org.mwptools.mwp"

was_armed = false

doc = Nokogiri::XML::Document.new
doc.encoding = 'utf-8'
m =  doc.create_element('gpx', :version => '1.0', :creator => "mwp-dbus-to-gpx")
m.add_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
m.add_namespace(nil, 'http://www.topografix.com/GPX/1/0')
m['xsi:schemaLocation']="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd"
doc.add_child(m)
m0 = m.add_child(doc.create_element('trk'))
m0.add_child(doc.create_element('src',
                                "Created by mwp-dbus-to-gpx"))
m0.add_child(doc.create_element('name', "mwplog"))
m1 = m0.add_child(doc.create_element('trkseg'))

loop = DBus::Main.new

mwp.on_signal("Quit") { loop.quit }

mwp.on_signal("StateChanged") do |state|
  if !was_armed and state > 0
    was_armed = true
  end
  if was_armed and state  == 0
    loop.quit
  end
end

mwp.on_signal("LocationChanged") do |lat,lon,alt|
  m2 = m1.add_child(doc.create_element('trkpt',
				       :lat => lat.to_s, :lon => lon.to_s))
  m2.add_child(doc.create_element('ele',alt.to_s))
  m2.add_child(doc.create_element('time', Time.now.gmtime.strftime("%FT%TZ")))
end



loop << bus
loop.run

puts doc.to_xml
