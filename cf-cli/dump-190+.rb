#!/usr/bin/ruby

# Public Domain : stronnag 2015-05-31

RATES = {0 => 0, 1 => 9600, 2 => 19200, 3 => 38400, 4 => 57600, 5 => 115200}

ports = {}
ARGF.each do |l|
  case l
  when /set serial_port_(\d+)_(\S+) = (\d+)/
    port = $1.to_i - 1
    act = $2.to_sym
    val = $3.to_i
    ports[port] ||= {}
    ports[port][act] = val
  when /set reboot_character/
    puts
    puts '# serial ports'
    ssn = 30
    ports.each do |k,v|
      portno = k
      next if ports.size == 5 and portno == 2
      if k > 1
	portno = ssn
	ssn += 1
      end
      puts "serial #{portno} #{v[:functions]} #{RATES[v[:msp_baudrate
]]} #{RATES[v[:gps_baudrate]]} #{RATES[v[:telemetry_baudrate]]} #{RATES[v[:blackbox_baudrate]]}"
    end
    puts
    puts l
  when /aux (\d+) (\d+) (\d+) (\d+) (\d+)/
    auxno = $1.to_i
    if auxno > 19
      min = $4.to_i
      max = $5.to_i
      if min != max and min != 900
	STDERR.puts "** Your modes settings are most likely broken -- review before flying (auxno= #{auxno}) **"
      end
    else
      puts l
    end
  else
    puts l
  end
end
