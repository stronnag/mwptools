#!/usr/bin/ruby

# Translates the **author's** serial settings from pre-1.8.0 to the new
# shiny settings. Patches for new translation welcome.
#
# (c) Jonathan Hudson 2015

BAUDS = {9600 => 1, 19200 => 2, 38400 => 3, 57600 => 4, 115200 => 5}

FUNCTION_NONE                = 0
FUNCTION_MSP                 = (1 << 0)
FUNCTION_GPS                 = (1 << 1)
FUNCTION_TELEMETRY_FRSKY     = (1 << 2)
FUNCTION_TELEMETRY_HOTT      = (1 << 3)
FUNCTION_TELEMETRY_MSP       = (1 << 4)
FUNCTION_TELEMETRY_SMARTPORT = (1 << 5)
FUNCTION_RX_SERIAL           = (1 << 6)
FUNCTION_BLACKBOX            = (1 << 7)

#  0   UNUSED
#  1   MSP, CLI, TELEMETRY, SMARTPORT TELEMETRY, GPS-PASSTHROUGH
#  2   GPS ONLY
#  3   RX SERIAL ONLY
#  4   TELEMETRY ONLY
#  5   MSP, CLI, GPS-PASSTHROUGH
#  6   CLI ONLY
#  7   GPS-PASSTHROUGH ONLY
#  8   MSP ONLY
#  9   SMARTPORT TELEMETRY ONLY
# 10  BLACKBOX ONLY
# 11  MSP, CLI, BLACKBOX, GPS-PASSTHROUGH

def rewrite_serial ports,rates
  ports.each do |k,v|
    case v
    when 0
      puts "set serial_port_#{k}_functions = #{FUNCTION_NONE}"
    when 1,8
      puts "set serial_port_#{k}_functions = #{FUNCTION_MSP}"
      msprate = (k > 1) ? 2 : BAUDS[rates[:msp]]
      puts "set serial_port_#{k}_msp_baudrate = #{msprate}"
      puts "set serial_port_#{k}_telemetry_baudrate = 0"
      puts "set serial_port_#{k}_blackbox_baudrate = 0"
      puts "set serial_port_#{k}_gps_baudrate = 0"
    when 2
      puts "set serial_port_#{k}_functions = #{FUNCTION_GPS}"
      puts "set serial_port_#{k}_msp_baudrate = 0"
      puts "set serial_port_#{k}_blackbox_baudrate = 0"
      puts "set serial_port_#{k}_telemetry_baudrate = 0"
      puts "set serial_port_#{k}_gps_baudrate = #{BAUDS[rates[:gps]]}"
    when 3
      puts "set_serial_port_#{k}_functions = #{FUNCTION_RX_SERIAL}"
      puts "set serial_port_#{k}_msp_baudrate = 0"
      puts "set serial_port_#{k}_telemetry_baudrate = 0"
      puts "set serial_port_#{k}_blackbox_baudrate = 0"
      puts "set serial_port_#{k}_gps_baudrate = 0"
    else
      STDERR.puts "Please fix port #{k} scenario = #{v} manually"
    end
  end
end

ports = {}
rates = {}

ARGF.each do |l|
  case l
  when /set serial_port_(\d+)_scenario = (\d+)/
    port = $1.to_i
    scen = $2.to_i
    ports[port] = scen
  when /set msp_baudrate = (\d+)/
    rates[:msp] = $1.to_i
  when /set cli_baudrate = (\d+)/
    rates[:cli] = $1.to_i
  when /set gps_baudrate = (\d+)/
    rates[:gps] = $1.to_i
  when /set gps_passthrough_baudrate = (\d+)/
    rates[:pass] = $1.to_i
  when /set gps_provider/
    rewrite_serial ports,rates
    puts l
  else
    puts l
  end
end
