#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'ap'

P_START = 0x7e
P_STUFF = 0x7d
P_MASK  = 0x20
P_SIZE = 10

DTYPE_MAP = {
  0x0700 => 'AccX_DATA_ID',
  0x0710 => 'AccY_DATA_ID',
  0x0720 => 'AccZ_DATA_ID',
  0x0A00 => 'ASS_SPEED_DATA_ID',
  0x0200 => 'FAS_CURR_DATA_ID',
  0x0210 => 'FAS_VOLT_DATA_ID',
  0x0300 => 'FLVSS_CELL_DATA_ID',
  0x0600 => 'FUEL_DATA_ID',
  0x0800 => 'GPS_LAT_LON_DATA_ID',
  0x0820 => 'GPS_ALT_DATA_ID',
  0x0830 => 'GPS_SPEED_DATA_ID',
  0x0840 => 'GPS_COG_DATA_ID',
  0xF103 => 'GPS_HDOP_DATA_ID',
  0x0400 => 'RPM_T1_DATA_ID',
  0x0410 => 'RPM_T2_DATA_ID',
  0x0500 => 'RPM_ROT_DATA_ID',
  0x0900 => 'SP2UARTB_ADC3_DATA_ID',
  0x0910 => 'SP2UARTB_ADC4_DATA_ID',
  0x0100 => 'VARIO_ALT_DATA_ID',
  0x0110 => 'VARIO_VSI_DATA_ID'
}

def parse_lat_lon val
  ap=nil
  bp=nil
  sgn=nil

  ll_b1w = (val & 0x3fffffff) / 10000
  ll_a1w = (val & 0x3fffffff) % 10000
  bp = (ll_b1w / 60 * 100) + (ll_b1w % 60)
  ap = ll_a1w
  case (val >> 30)
  when 0
    sgn = "N"
  when 1
    sgn = "S"
  when 2
    sgn = "E"
  when 3
    sgn = "W"
  end
  "#{bp} #{ap} #{sgn}"
end

def parse_data dtype,dval
  rval = dval ## for cases we can't parse
  unit='raw'
  case dtype
  when 0x0700, 0x0710, 0x0720 # 'Acc*_DATA_ID',
    dval = [dval].pack('S').unpack('s')[0]
    rval = "%.2f" % (dval / 100.0)
    unit = 'g'
  when 0x0A00 # 'ASS_SPEED_DATA_ID',
  when 0x0200 # 'FAS_CURR_DATA_ID',
  when 0x0210 # 'FAS_VOLT_DATA_ID',
    rval = "%.1f" % (dval / 100.0)
    unit='V'
  when 0x0300 # 'FLVSS_CELL_DATA_ID',
  when 0x0600 # 'FUEL_DATA_ID',
  when 0x0800 # 'GPS_LAT_LON_DATA_ID',
    rval = parse_lat_lon dval
    unit = 'pos'
  when 0x0820 # 'GPS_ALT_DATA_ID',
    dval = [dval].pack('S').unpack('s')[0]
    rval = "%.1f" % (dval / 100.0)
    unit = 'm'
  when 0x0830 # 'GPS_SPEED_DATA_ID',
    rval = "%.2f" % ((dval/1000.0)*0.51444444)
    unit = 'm/s'
  when 0x0840 # 'GPS_COG_DATA_ID',
    rval = "%.1f" % (dval / 100.0)
    unit = '°'
  when 0xF103 # 'GPS_HDOP_DATA_ID',
  when 0x0400 # 'RPM_T1_DATA_ID',
  when 0x0410 # 'RPM_T2_DATA_ID',
  when 0x0500 # 'RPM_ROT_DATA_ID',
  when 0x0900 # 'SP2UARTB_ADC3_DATA_ID',
  when 0x0910 # 'SP2UARTB_ADC4_DATA_ID',
  when 0x0100 # 'VARIO_ALT_DATA_ID',
  when 0x0110 # 'VARIO_VSI_DATA_ID'
  end
  [rval,unit]
end

def check_crc arry
  crc=0
  2.upto(9).each do |n|
    b = arry[n]
    crc = crc + b
    crc = crc + (crc >> 8)
    crc = (crc & 0xff)
  end
  (crc == 0xff)
end

def process_packet pkt
  crc_ok = check_crc pkt
  sensor_id = pkt[1]
  fs = pkt[2]
  dtype = pkt[3,2].pack('C*').unpack('S')[0]
  dval = pkt[5,4].pack('C*').unpack('L')[0]
  dtext = DTYPE_MAP[dtype] || "UNKNOWN"
  if crc_ok
    rval,units = parse_data dtype, dval
    str = "* type %02x %04x %s %x" % [sensor_id,dtype,dtext,dval]
    str << " #{rval} #{units}"
    puts str
  else
    puts "CRC failure #{dtext} (#{"%04x" % dtype})"
  end
  crc_ok
end

data = IO.binread(ARGV[0])

stuffed = false
good = bad = short = 0
packet=[]

data.each_byte do |b|
  if b == P_START
    if packet.size == P_SIZE
      res = process_packet packet
      if res
        good += 1
      else
        bad += 1
      end
    else
      short += 1
      puts "Invalid packet #{packet.size}b"
    end
    packet = []
  end
  if stuffed
    b = b ^ P_MASK
    stuffed = false
  elsif b == P_STUFF
    stuffed = true
  end
  packet << b unless stuffed
end
STDERR.puts "Total/good/bad/short: #{good+bad+short} / #{good} / #{bad} / #{short}"
