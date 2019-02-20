#!/usr/bin/env ruby

# Copyright (c) 2015 Jonathan Hudson <jh+mwptools@daria.co.uk>

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'csv'
require 'optparse'
require 'socket'
require 'open3'
require 'json'
require_relative 'inav_states'

begin
require 'rubyserial'
  noserial = false;
rescue LoadError
  noserial = true;
end

class Serial
  # Expose the rubyserial file descriptor for select(3) on POSIX systems.
  def getfd
    @fd
  end
end

#STDERR_LOG="/tmp/replay_bblog_stderr.txt"
LLFACT=10000000
ALTFACT=100
MINDELAY=0.001
NORMDELAY=0.1
$verbose = false
$vbatscale=1.0

BOARD_MAP = {
  'AIRBOTF4' => {:names=>["AIRBOTF4"], :id=>"ABF4"},
  'AIRHEROF3' => {:names=>["AIRHEROF3", "AIRHEROF3_QUAD"], :id=>"AIR3"},
  'ALIENFLIGHTF3' => {:names=>["ALIENFLIGHTF3"], :id=>"AFF3"},
  'ALIENFLIGHTF4' => {:names=>["ALIENFLIGHTF4"], :id=>"AFF4"},
  'ALIENFLIGHTNGF7' => {:names=>["ALIENFLIGHTNGF7"], :id=>"AFF7"},
  'ANYFC' => {:names=>["ANYFC"], :id=>"ANYF"},
  'ANYFCF7' => {:names=>["ANYFCF7", "ANYFCF7_EXTERNAL_BARO"], :id=>"ANY7"},
  'ANYFCM7' => {:names=>["ANYFCM7"], :id=>"ANYM"},
  'ASGARD32F4' => {:names=>["ASGARD32F4"], :id=>"ASF4"},
  'ASGARD32F7' => {:names=>["ASGARD32F7"], :id=>"ASF4"},
  'BEEROTORF4' => {:names=>["BEEROTORF4"], :id=>"BRF4"},
  'BETAFLIGHTF3' => {:names=>["BETAFLIGHTF3"], :id=>"BFF3"},
  'BETAFLIGHTF4' => {:names=>["BETAFLIGHTF4"], :id=>"BFF4"},
  'BLUEJAYF4' => {:names=>["BLUEJAYF4"], :id=>"BJF4"},
  'CHEBUZZF3' => {:names=>["CHEBUZZF3"], :id=>"CHF3"},
  'CLRACINGF4AIR' => {:names=>["CLRACINGF4AIR", "CLRACINGF4AIRV2", "CLRACINGF4AIRV3"], :id=>"CLRA"},
  'COLIBRI' => {:names=>["COLIBRI", "QUANTON"], :id=>"COLI"},
  'COLIBRI_RACE' => {:names=>["COLIBRI_RACE"], :id=>"CLBR"},
  'DALRCF405' => {:names=>["DALRCF405"], :id=>"DLF4"},
  'F4BY' => {:names=>["F4BY"], :id=>"F4BY"},
  'FALCORE' => {:names=>["FALCORE"], :id=>"FLCR"},
  'FF_F35_LIGHTNING' => {:names=>["FF_F35_LIGHTNING"], :id=>"FF35"},
  'FF_FORTINIF4' => {:names=>["FF_FORTINIF4"], :id=>"FORT"},
  'FF_PIKOF4' => {:names=>["FF_PIKOF4", "FF_PIKOF4OSD"], :id=>"PIK4"},
  'FIREWORKSV2' => {:names=>["FIREWORKSV2"], :id=>"FWX2"},
  'FISHDRONEF4' => {:names=>["FISHDRONEF4"], :id=>"FDV1"},
  'FRSKYF3' => {:names=>["FRSKYF3"], :id=>"FRF3"},
  'FRSKYF4' => {:names=>["FRSKYF4"], :id=>"FRF4"},
  'FURYF3' => {:names=>["FURYF3", "FURYF3_SPIFLASH"], :id=>"FYF3"},
  'KAKUTEF4' => {:names=>["KAKUTEF4", "KAKUTEF4V2"], :id=>"KTV1"},
  'KAKUTEF7' => {:names=>["KAKUTEF7"], :id=>"KTF7"},
  'KFC32F3_INAV' => {:names=>["KFC32F3_INAV"], :id=>"KFCi"},
  'KISSFC' => {:names=>["KISSFC"], :id=>"KISSFC"},
  'KROOZX' => {:names=>["KROOZX"], :id=>"KROOZX"},
  'LUX_RACE' => {:names=>["LUX_RACE"], :id=>"LUX"},
  'MATEKF405' => {:names=>["MATEKF405", "MATEKF405OSD", "MATEKF405_SERVOS6"], :id=>"MKF4"},
  'MATEKF405SE' => {:names=>["MATEKF405SE"], :id=>"MF4S"},
  'MATEKF411' => {:names=>["MATEKF411", "MATEKF411_RSSI", "MATEKF411_SFTSRL2"], :id=>"MK41"},
  'MATEKF722' => {:names=>["MATEKF722", "MATEKF722_HEXSERVO"], :id=>"MKF7"},
  'MATEKF722SE' => {:names=>["MATEKF722SE"], :id=>"MF7S"},
  'MOTOLAB' => {:names=>["MOTOLAB"], :id=>"MOTO"},
  'OMNIBUS' => {:names=>["OMNIBUS"], :id=>"OMNI"},
  'OMNIBUSF4' => {:names=>["DYSF4PRO", "DYSF4PROV2", "OMNIBUSF4", "OMNIBUSF4PRO", "OMNIBUSF4PRO_LEDSTRIPM5", "OMNIBUSF4V3"], :id=>"OBF4"},
  'OMNIBUSF7' => {:names=>["OMNIBUSF7", "OMNIBUSF7V2"], :id=>"OBF7"},
  'OMNIBUSF7NXT' => {:names=>["OMNIBUSF7NXT"], :id=>"ONXT"},
  'PIKOBLX' => {:names=>["PIKOBLX"], :id=>"PIKO"},
  'PIXRACER' => {:names=>["PIXRACER"], :id=>"PXR4"},
  'QUARKVISION' => {:names=>["QUARKVISION"], :id=>"QRKV"},
  'RADIX' => {:names=>["RADIX"], :id=>"RADIX"},
  'RCEXPLORERF3' => {:names=>["RCEXPLORERF3"], :id=>"REF3"},
  'REVO' => {:names=>["REVO"], :id=>"REVO"},
  'RMDO' => {:names=>["RMDO"], :id=>"RMDO"},
  'SPARKY' => {:names=>["SPARKY"], :id=>"SPKY"},
  'SPARKY2' => {:names=>["SPARKY2"], :id=>"SPK2"},
  'SPEEDYBEEF4' => {:names=>["SPEEDYBEEF4"], :id=>"SBF4"},
  'SPRACINGF3' => {:names=>["SPRACINGF3"], :id=>"SRF3"},
  'SPRACINGF3EVO' => {:names=>["SPRACINGF3EVO", "SPRACINGF3EVO_1SS"], :id=>"SPEV"},
  'SPRACINGF3MINI' => {:names=>["SPRACINGF3MINI"], :id=>"SRFM"},
  'SPRACINGF3NEO' => {:names=>["SPRACINGF3NEO"], :id=>"SP3N"},
  'SPRACINGF4EVO' => {:names=>["SPRACINGF4EVO"], :id=>"SP4E"},
  'SPRACINGF7DUAL' => {:names=>["SPRACINGF7DUAL"], :id=>"SP7D"},
  'STM32F3DISCOVERY' => {:names=>["STM32F3DISCOVERY"], :id=>"SDF3"},
  'YUPIF4' => {:names=>["YUPIF4", "YUPIF4MINI", "YUPIF4R2"], :id=>"YPF4"},
  'YUPIF7' => {:names=>["YUPIF7"], :id=>"YPF7"},
  'MATEKF4' => {:names=>["MATEKF4"], :id=>"MKF4"},
  'NAZE' => {:names=>["NAZE"], :id=>"AFNA"},
  'ALIENWIIF3' => {:names=>["ALIENWIIF3"], :id=>"AWF3"},
  'OLIMEXINO' => {:names=>["OLIMEXINO"], :id=>"OLI1"},
  'PIKOBLX_limited' => {:names=>["PIKOBLX_limited"], :id=>"PIKO"},
  'CJMCU' => {:names=>["CJMCU"], :id=>"CJM1"},
  'CRAZEPONYMINI' => {:names=>["CRAZEPONYMINI"], :id=>"CPM1"},
  'EUSTM32F103RC' => {:names=>["EUSTM32F103RC"], :id=>"EUF1"},
  'PORT103R' => {:names=>["PORT103R"], :id=>"103R"},
  'CC3D' => {:names=>["CC3D"], :id=>"CC3D"},
  }

def start_io dev
  if RUBY_PLATFORM.include?('cygwin') || !Gem.win_platform?
    # Easy way for sane OS (Linux, OSX, FreeBSD, POSIX in general)
    res = select [STDIN,dev[:io]],nil,nil,nil
    case res[0][0]
    when dev[:io]
      if dev[:type] == :ip
	res = dev[:io].recvfrom(256)
	dev[:host] = res[1][3]
	dev[:port] = res[1][1].to_i
      end
    end
  else
    # Ugly way for Windows
    require 'win32api'
    t1=t2 = nil
    res=nil
    t1 = Thread.new do
      kbhit = Win32API.new('crtdll', '_kbhit', [ ], 'I')
        loop do
	break if kbhit.Call == 1
	sleep 0.1
      end
      t2.kill
    end
    t2 = Thread.new do
      if dev[:type] == :ip
          res = dev[:io].recvfrom(256)
	t1.kill
	dev[:host] = res[1][3]
	dev[:port] = res[1][1].to_i
      else
	dev[:serp].read(1)
	t1.kill
      end
      end
    t1.join
    t2.join
    if dev[:type] == :ip
	puts "peer #{dev[:host]}:#{dev[:port]}"
    end
  end
end

def mksum s
  ck = 0
  s.each_byte {|c| ck ^= c}
  ck
end

def send_msg dev, msg
  if !dev.nil? and !msg.nil?
    case dev[:type]
    when :ip
      dev[:io].send msg, 0, dev[:host], dev[:port]
    when :tty
      dev[:serp].write(msg)
    when :fd
      dev[:io].syswrite(msg)
    end
  end
end

def send_init_seq skt,typ,snr=false,baro=true,mag=true,gitinfo=nil

  msps = [
    # $     M    >     len   msg
    [0x24, 0x4d, 0x3e, 0x07, 0x64, 0xe7, 0x01, 0x00, 0x3c, 0x00, 0x00, 0x80, 0],
    [0x24, 0x4d, 0x3e, 0x03, 0x01, 0x00, 0x00, 0x0, 0x0d],
    [0x24, 0x4d, 0x3e, 0x06, 0x04, 0x55, 0x4E, 0x4B, 0, 0, 0, 0],
    [0x24, 0x4d, 0x3e, 0x04, 0x02, 0x49, 0x4e, 0x41, 0x56, 0x16],
    [0x24, 0x4d, 0x3e, 0x03, 0x03, 0, 42, 0x00, 42], # obviously fake
    [0x24, 0x4d, 0x3e, 0x1a, 0x05, 0x4d, 0x61, 0x79, 0x20, 0x32, 0x31, 0x20, 0x32, 0x30, 0x31, 0x36, 0x31, 0x32, 0x3a, 0x34, 0x37, 0x3a, 0x31, 0x37,0,0,0,0,0,0,0,0x2a],
    [0x24,0x4d,0x3e,0x9f,0x74,0x41,0x52,0x4d,0x3b,0x41,0x4e,0x47,0x4c,0x45,0x3b,0x48,0x4f,0x52,0x49,0x5a,0x4f,0x4e,0x3b,0x41,0x49,0x52,0x20,0x4d,0x4f,0x44,0x45,0x3b,0x48,0x45,0x41,0x44,0x49,0x4e,0x47,0x20,0x4c,0x4f,0x43,0x4b,0x3b,0x4d,0x41,0x47,0x3b,0x48,0x45,0x41,0x44,0x46,0x52,0x45,0x45,0x3b,0x48,0x45,0x41,0x44,0x41,0x44,0x4a,0x3b,0x4e,0x41,0x56,0x20,0x41,0x4c,0x54,0x48,0x4f,0x4c,0x44,0x3b,0x53,0x55,0x52,0x46,0x41,0x43,0x45,0x3b,0x4e,0x41,0x56,0x20,0x50,0x4f,0x53,0x48,0x4f,0x4c,0x44,0x3b,0x4e,0x41,0x56,0x20,0x52,0x54,0x48,0x3b,0x4e,0x41,0x56,0x20,0x57,0x50,0x3b,0x48,0x4f,0x4d,0x45,0x20,0x52,0x45,0x53,0x45,0x54,0x3b,0x47,0x43,0x53,0x20,0x4e,0x41,0x56,0x3b,0x42,0x45,0x45,0x50,0x45,0x52,0x3b,0x4f,0x53,0x44,0x20,0x53,0x57,0x3b,0x42,0x4c,0x41,0x43,0x4b,0x42,0x4f,0x58,0x3b,0x46,0x41,0x49,0x4c,0x53,0x41,0x46,0x45,0x3b,0xa7],
    [0x24, 0x4d, 0x3e, 11,   101,  0, 0, 0, 0, 0, 0, 4,0,0,0, 0, 0], # obviously fake
  ]

  sensors = (1|8)
  sensors |= 2  if baro
  sensors |= 4  if mag
  sensors |= 16 if snr

  msps[7][9] = sensors
  msps[0][6] = typ if typ

  unless gitinfo.nil?
    if gitinfo.size == 7 or  gitinfo.size == 8
      i = 0
      gitinfo.each_byte {|b| msps[5][24+i] = b ; i += 1}
    else
      if m=gitinfo.match(/^INAV (\d{1})\.(\d{1})\.(\d{1}) \(([0-9A-Fa-f]*)\) (\S+)/)
	msps[4][5] = m[1][0].ord - '0'.ord
	msps[4][6] = m[2][0].ord - '0'.ord
	msps[4][7] = m[3][0].ord - '0'.ord
	iv = [m[1],m[2],m[3]].join('.')
	i = 0
	if m[4].size < 7
	  i = 1
	  msps[5][3] = 19
	  msps[5][24] = 0
	else
	  m[4].each_byte {|b| msps[5][24+i] = b ; i += 1}
	  msps[5][3] = 18 + m[4].length
	end
	bname = m[5].upcase
	bid = nil
	BOARD_MAP.each do |k,v|
	  v[:names].each do |vn|
	    if vn == bname
	      bid = v[:id]
	      break
	    end
	  end
	  break if bid
	end
	bnl = bname.length
	if bid
	  i = 0
	  bid.each_byte {|b| msps[2][5+i] = b; i+= 1}
	end
	msps[2][11] = 0
	msps[2][12] = 0
	msps[2][13] = bnl
	i = 14
	bname.each_byte do |b|
	  msps[2][i]=b
	  i += 1
	end
	msps[2][3] = 9 + bnl
	msps[2][i] = 0
      end
    end
  end
  msps.each do |msp|
    len = msp[3]
    msp[len+5] = mksum msp[3,len+2].pack('C*')
    send_msg skt, msp.pack('C*')
    sleep 0.01
  end

  inavers =  get_state_version iv
  if $verbose
    STDERR.puts "iv = #{iv} state vers = #{inavers}"
  end
  return inavers
end

def encode_atti r, gpshd=0
  msg='$TA'
  hdr = (gpshd == 1) ? r[:gps_ground_course].to_i : r[:attitude2].to_i/10
  pt =  r[:attitude1].to_i/10
  rl = r[:attitude0].to_i/10
  sl = [pt, rl, hdr].pack("s<s<s<")
#  STDERR.puts "p=#{pt} r=#{rl} h=#{hdr}"
  msg << sl << mksum(sl)
  msg
end

def encode_gps r,baro=true
  msg='$TG'
  nsf = 0
  ns = r[:gps_numsat].to_i
  if r.has_key? :gps_fixtype
    nsf = r[:gps_fixtype].to_i + 1
  else
    nsf = case ns
	  when 0
	    0
	  when 1,2,3,4
	    1
	  when 5,6
	    2
	  else
	    3
	  end
  end
  nsf |= (ns << 2)
  alt = 0
  if baro
    alt = r[:baroalt_cm].to_i
  else
    gps_alt = r[:gps_altitude].to_i
    if @base_alt == nil
      @base_alt = gps_alt
    end
    alt = (gps_alt - @base_alt)*100
  end

  sl = [(r[:gps_coord0].to_f*LLFACT).to_i,
    (r[:gps_coord1].to_f*LLFACT).to_i,
    r[:gps_speed_ms].to_i,
    alt, nsf].pack('l<l<CL<c')
  msg << sl << mksum(sl)
  msg
end

def encode_origin r
  msg='$TO'
  sl = [(r[:lat].to_f*LLFACT).to_i,
    (r[:lon].to_f*LLFACT).to_i,
    (r[:alt].to_f*ALTFACT).to_i,
    1,1].pack('l<l<L<cc')
  msg << sl << mksum(sl)
  msg
end

def encode_et et
  msg='$Tq'
  sl = [et].pack('S')
  msg << sl << mksum(sl)
  msg
end

def encode_x d=0
  msg='$Tx'
  sl = [d].pack('c')
  msg << sl << mksum(sl)
  msg
end

def encode_stats r,inavers,armed=1
  msg='$TS'
  sts = nil

  sts = case INAV_STATES[inavers][r[:navstate].to_i]
	when :nav_state_undefined,:nav_state_idle,
	    :nav_state_waypoint_finished,
	    :nav_state_launch_wait,
	    :nav_state_launch_in_progress
	  0 # get from flightmode
	when :nav_state_althold_initialize,
	    :nav_state_althold_in_progress
	  8
	when :nav_state_poshold_2d_initialize,
	    :nav_state_poshold_2d_in_progress,
	    :nav_state_poshold_3d_initialize,
	    :nav_state_poshold_3d_in_progress
	  9
	when  :nav_state_rth_initialize,
	    :nav_state_rth_climb_to_safe_alt,
	    :nav_state_rth_head_home,
	    :nav_state_rth_hover_prior_to_landing,
	    :nav_state_rth_finishing,
	    :nav_state_rth_finished,
	    :nav_state_rth_2d_initialize,
	    :nav_state_rth_3d_initialize,
	    :nav_state_rth_2d_head_home,
	    :nav_state_rth_3d_head_home,
	    :nav_state_rth_3d_climb_to_safe_alt
	  13
	when :nav_state_rth_landing,
	    :nav_state_rth_3d_landing,
	    :nav_state_waypoint_rth_land,
	    :nav_state_emergency_landing_initialize,
	    :nav_state_emergency_landing_in_progress,
	    :nav_state_emergency_landing_finished
	  15
	when :nav_state_waypoint_initialize,
	    :nav_state_waypoint_pre_action,
	    :nav_state_waypoint_in_progress,
	    :nav_state_waypoint_reached,
	    :nav_state_waypoint_next
	  10
	when :nav_state_cruise_2d_initialize,
	    :nav_state_cruise_2d_in_progress,
	    :nav_state_cruise_2d_adjusting,
	    :nav_state_cruise_3d_initialize,
	    :nav_state_cruise_3d_in_progress,
	    :nav_state_cruise_3d_adjusting
	  18
	else
	  19
	end

  if $verbose && sts == 19
    STDERR.puts "** STS 19 for #{INAV_STATES[inavers][r[:navstate].to_i]}\n"
  end

  sts = (sts << 2) | armed
  if r[:failsafephase_flags].strip != 'IDLE'
    sts |= 2
  end

  rssi = r[:rssi].to_i * 254 / 1023

  vbat = 0
  if r.has_key? :vbatlatest_v
    vbat = r[:vbatlatest_v].to_f
  elsif r.has_key? :vbat_v
    vbat = r[:vbat_v].to_f
  elsif r.has_key? :vbat
    vbat = r[:vbat].to_f / 100.0
  end

  mah = (r.has_key? :energycumulative_mah) ? r[:energycumulative_mah].to_i : 0
  mah = mah & 0xffff

  sl = [(vbat*$vbatscale*1000).to_i, mah, rssi, 0, sts].pack('S<S<CCC')
  msg << sl << mksum(sl)
  msg
end

def encode_amps r
  amps = nil
  msg = nil
  if r.has_key? :amperagelatest_a
    amps = r[:amperagelatest_a].to_f
  elsif r.has_key? :amperage_a
    amps = r[:amperage_a].to_f
  end
  if amps and amps > 0
    msg='$Ta'
    sl = [(amps*100).to_i].pack('S')
    msg << sl << mksum(sl)
  end
  msg
end
#@xs=-1

def encode_nav r,inavers
  msg='$TN'
  gpsmode = case INAV_STATES[inavers][r[:navstate].to_i]
	    when :nav_state_poshold_2d_initialize,
		:nav_state_poshold_2d_in_progress,
		:nav_state_poshold_3d_initialize,
		:nav_state_poshold_3d_in_progress
	      1
	    when :nav_state_rth_initialize,
		:nav_state_rth_2d_initialize,
		:nav_state_rth_2d_head_home,
		:nav_state_rth_2d_gps_failing,
		:nav_state_rth_2d_finishing,
		:nav_state_rth_2d_finished,
		:nav_state_rth_3d_initialize,
		:nav_state_rth_3d_climb_to_safe_alt,
		:nav_state_rth_3d_head_home,
		:nav_state_rth_3d_gps_failing,
		:nav_state_rth_3d_hover_prior_to_landing,
		:nav_state_rth_3d_landing,
		:nav_state_rth_3d_finishing,
		:nav_state_rth_3d_finished
	      2
	    when :nav_state_waypoint_initialize,
		:nav_state_waypoint_pre_action,
		:nav_state_waypoint_in_progress,
		:nav_state_waypoint_reached,
		:nav_state_waypoint_next,
		:nav_state_waypoint_finished,
		:nav_state_waypoint_rth_land
	      3
	    else
	      0
	    end

  navmode = case INAV_STATES[inavers][r[:navstate].to_i]
	    when :nav_state_althold_initialize,
		:nav_state_althold_in_progress
	      99
	    when :nav_state_poshold_2d_initialize,
		:nav_state_poshold_2d_in_progress,
		:nav_state_poshold_3d_initialize,
		:nav_state_poshold_3d_in_progress
	      3
	    when :nav_state_rth_initialize,
		:nav_state_rth_2d_initialize,
		:nav_state_rth_3d_initialize,
		:nav_state_rth_head_home,
		:nav_state_rth_2d_head_home,
		:nav_state_rth_3d_head_home,
		:nav_state_rth_3d_climb_to_safe_alt,
		:nav_state_rth_climb_to_safe_alt
	      1
	    when :nav_state_rth_3d_hover_prior_to_landing,
		:nav_state_rth_hover_prior_to_landing
	      8
	    when :nav_state_rth_3d_landing,
		:nav_state_waypoint_rth_land,
		:nav_state_emergency_landing_in_progress,
		:nav_state_rth_landing,
		:nav_state_rth_3d_finishing
	      9
	    when :nav_state_waypoint_rth_land,
		:nav_state_emergency_landing_finished
	      10
	    when :nav_state_waypoint_initialize,
		:nav_state_waypoint_pre_action,
		:nav_state_waypoint_in_progress,
		:nav_state_waypoint_reached,
		:nav_state_waypoint_next
	      5
	    else
	      0
	    end

  if $verbose
    STDERR.puts "state #{r[:navstate].to_i} #{INAV_STATES[inavers][r[:navstate].to_i]}" if INAV_STATES[inavers][r[:navstate].to_i] != @xs
    @xs = INAV_STATES[inavers][r[:navstate].to_i]
  end

  navact = case gpsmode
	   when 3
	     1
	   when 1
	     2
	   when 2
	     4
	   else
	     0
	   end
  sl = [gpsmode,navmode,navact,0,0,0].pack('CCCCCC')
  msg << sl << mksum(sl)
  msg
end

def encode_extra r
  msg='$TX'
  hf=0
  if r.has_key? :hwhealthstatus
    val=r[:hwhealthstatus].to_i
    0.upto(6) do |n|
      sv = val & 3
      hf = 1 if sv > 1 or ((n < 2 or n == 4) and sv != 1)
      val = (val >> 2)
    end
  end
  sl = [r[:gps_hdop].to_i,hf,0,0,0].pack('vCCCC')
  msg << sl << mksum(sl)
  msg
end

def get_autotype nmotor, nservo
  mtyp = 0
  mtyp =   case nmotor
	    when 1,2
	      mtyp = (nservo == 4) ? 14 : 8
	    when 3
	      mtyp = 1
	    when 4
	      mtyp = 3
	    when 6
	      mtyp = 7
	    when 8
	      mtyp = 11
	    end
  mtyp
end

if RUBY_VERSION.match(/^1/)
  abort "This script requires a miniumum of Ruby 2.0"
end

idx = 1
decl = nil
typ = 3
udpspec = nil
serdev = nil
v4 = false
gpshd = 0
mindelay = false
childfd = nil
autotyp=nil
dumph = false
scan = nil
decoder="blackbox_decode"
nobaro = nil

pref_fn = File.join(ENV["HOME"],".config", "mwp", "replay_ltm.json")
if File.exist? pref_fn
  json = IO.read(pref_fn)
  prefs = JSON.parse(json, {:symbolize_names => true})
  decl = prefs[:declination].to_f
  autotyp = prefs[:auto]
  nobaro = prefs[:nobaro]
end

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] file\nReplay bbox log as LTM"
  opt.on('-u','--udp=ADDR',String,"udp target (localhost:3000)"){|o|udpspec=o}
  opt.on('-s','--serial-device=DEV'){|o|serdev=o}
  opt.on('-i','--index=IDX',Integer){|o|idx=o}
  opt.on('-t','--vehicle-type=TYPE',Integer){|o|typ=o}
  opt.on('-d','--declination=DEC',Float,'Mag Declination (default 0)'){|o|decl=o}
  opt.on('-g','--use-gps-heading','Use GPS course instead of compass'){gpshd=1}
  opt.on('-G','--use-gps-alt','Use GPS alt instead of baro'){nobaro=true}
  opt.on('-4','--force-ipv4'){v4=true}
  opt.on('-f','--fast'){mindelay=true}
  opt.on('-d','--dump-headers'){dumph=true}
  opt.on('-v','--verbose'){$verbose=true}
  opt.on('-S', '--scan-only'){scan = true}
  opt.on('--fd=FD',Integer){|o| childfd=o}
  opt.on('--decoder=NAME'){|o|decoder=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

dev = nil
intvl = 100000
nv = 0
icnt = 0
origin = nil

if mindelay
  mindelay = MINDELAY
  unless ENV['BB_DELAY'].nil?
    mindelay = ENV['BB_DELAY'].to_f
  end
end

unless ENV['BB_NOBARO'].nil?
  nobaro = true
end

RDISARMS = %w/NONE TIMEOUT STICKS SWITCH_3D SWITCH KILLSWITCH FAILSAFE NAVIGATION/

begin
  Open3.capture3("#{decoder} --help")
rescue
  abort "Can't run 'blackbox_decode' is it installed and on the PATH?"
end

bbox = (ARGV[0]|| abort('no BBOX log'))
have_mag = true

gitinfos=[]
disarms=[]
need_vbat_scale = true # pre 2.0
vbstate = false # true means we're 2.0.0 and need to check date
ivers = nil

File.open("/tmp/.mwp-vbat.txt","a") do |vf|
  File.open(bbox,'rb') do |f|
    f.each do |l|
      if m = l.match(/^H Firmware revision:(.*)$/)
	gitinfos << m[1]
	ivers = m[1]
	if iv=ivers.match(/INAV (\d+).(\d+).(\d+)/)
	  if iv[1].to_i <  2
	    need_vbat_scale = true
	  elsif iv[1].to_i == 2 and iv[2] == '0' and iv[2] == '0'
	    vbstate = true
	  else
	    need_vbat_scale = false
	  end
	end
      elsif m = l.match(/^H Firmware date:(...) (\d{2}) (\d{4})/)
	vf.puts "#{vbstate} #{m[0]}"
	if vbstate == true
	  if m[3] == '2018'
	    if m[1] == 'Apr' || m[1] == 'May' || m[1] == 'Jun' ||
		(m[1] == 'Jul' and m[2].to_i < 7)
	      need_vbat_scale = true
	    else
	      need_vbat_scale = false
	    end
	  end
	end
      elsif m = l.match(/^H mag_hardware:(\d+)$/)
	have_mag = m[1] != '0'
      elsif m = l.match(/^H vbat_scale:(\d+)$/)
	if need_vbat_scale
	  $vbatscale = m[1].to_f / 110.0
	end
      elsif m = l.match(/End of log \(disarm reason:(\d+)/)
	disarms << m[1].to_i
      end
    end
  end
  vf.puts "#{ivers} vbat scale #{need_vbat_scale}"
end

if scan
  mx = [gitinfos.size, disarms.size].max
  0.upto(mx - 1) do |i|
    puts "#{i+1} #{gitinfos[i]}, disarm on #{RDISARMS[disarms[i]]}"
  end
  exit
end

unless dumph
if udpspec
  fd = nil
  dev = {:type => :ip, :mode => nil}
  h = p = nil
  if(m = udpspec.match(/(?:udp:\/\/)?(\S*)?:{1}(\d+)/))
    h = m[1]
    p = m[2].to_i
  else
    abort "can't parse UDP spec"
  end
  addrs = Socket.getaddrinfo(nil, p,nil,:DGRAM)
  if v4 == false && addrs[0][0] == 'AF_INET6'
   fd = UDPSocket.new Socket::AF_INET6
    if h.empty?
      h = '::'
      dev[:mode] = :bind
    end
  else
    fd = UDPSocket.new
    if h.empty?
      h = ''
      dev[:mode] = :bind
    end
  end
  if dev[:mode] == :bind
    fd.bind(h, p)
  else
    fd.connect(h, p)
    dev[:host] = h
    dev[:port] = p
  end
  dev[:io] = fd
elsif serdev
  if noserial == true
    abort "No rubyserial gem found"
  end
  sdev,baud = serdev.split('@')
  baud ||= 115200
  baud = baud.to_i
  serialport = Serial.new sdev,baud
  dev = {:type => :tty, :serp => serialport}
  if !Gem.win_platform?
    sfd = serialport.getfd
    dev[:io] = IO.new(sfd)
  end
elsif childfd
  dev = {:type => :fd, :io => IO.new(childfd)}
else
  abort 'no device / UDP port'
end

if (dev[:type] == :tty || dev[:type] == :fd || dev[:mode] == :bind)
  print "Waiting for GS to start : "
  start_io dev
  if dev[:mode] == :bind and (dev[:host].nil? or dev[:host].empty?)
    puts "UDP peer is undefined"
    exit
  else
    puts ' ... OK'
  end
end
end

nul="/dev/null"
csv_opts = {
  :col_sep => ",",
  :headers => :true,
  :header_converters => ->(f){f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
  :return_headers => true}

if Gem.win_platform?
  nul = "NUL"
  csv_opts[:row_sep] = "\r\n" if RUBY_PLATFORM.include?('cygwin')
end
cmd = decoder
cmd << " --index #{idx}"
cmd << " --merge-gps"
unless decl.nil?
  cmd << " --declination-dec #{decl}"
end
cmd << " --stdout"
cmd << " 2>#{nul}"
cmd << " \"#{bbox}\""

lastr =nil
llat = 0.0
llon = 0.0
vers=nil
us=nil
st=nil

puts cmd
IO.popen(cmd,'rt') do |pipe|
  csv = CSV.new(pipe, csv_opts)
  lindex = 0
  csv.each do |row|
    if lindex == 0
      hdrs = row
      if dumph
	require 'ap'
	ap hdrs
	exit
      end
      abort 'Not a useful INAV log' if hdrs[:gps_coord0].nil?

#  if !$stderr.isatty
#    $stderr.reopen(STDERR_LOG, 'w')
#    $stderr.sync
#  end

      nmotor = 0
      nservo = 0
      0.upto(7).each do |n|
	s = "motor#{n}"
	if hdrs.has_key?(s.to_sym)
	  nmotor +=1
	end
      end
      0.upto(7).each do |n|
	s = "servo#{n}"
	nservo +=1 if hdrs.has_key?(s.to_sym)
      end

      if autotyp || typ == -1
	typ = get_autotype nmotor, nservo
      end

#  STDERR.puts "typ #{typ} motors #{nmotor} servos #{nservo}\n"

      have_sonar = (hdrs.has_key? :sonarraw)
      unless nobaro
	have_baro = (hdrs.has_key? :baroalt_cm)
      end
      gpshd = 1 if have_mag == false and gpshd == 0

      vers = send_init_seq dev,typ,have_sonar,have_baro,have_mag,gitinfos[idx-1]
    else
      next if row[:gps_numsat].to_i == 0
      us = row[:time_us].to_i
      st = us if st.nil?
      if us > nv
	nv = us + intvl
	icnt  = (icnt + 1) % 10
	# Check for armed and GPS (for origin)
	if origin.nil? and row[:gps_numsat].to_i > 5
	  origin = {:lat => row[:gps_coord0], :lon => row[:gps_coord1],
	    :alt => row[:gps_altitude]}
	  msg = encode_origin origin
	  send_msg dev, msg
	end
	msg = encode_atti row, gpshd
	send_msg dev, msg
	case icnt
	when 0,2,4,6,8
	  llat = row[:gps_coord0].to_f
	  llon = row[:gps_coord1].to_f
	  if  llat != 0.0 and llon != 0.0
	    msg = encode_gps row, have_baro
	    send_msg dev, msg
	  end
	when 5
	  if  llat != 0.0 and llon != 0.0 && origin
	    msg = encode_origin origin
	    send_msg dev, msg
	end
	  if row.has_key? :gps_hdop
	    msg = encode_extra row
	    send_msg dev, msg
	  end
	when 1,3,7,9
	  if  llat != 0.0 and llon != 0.0
	    lastr = row
	    msg = encode_amps row
	    if msg
	      send_msg dev, msg
	    end
	    msg = encode_stats row,vers
	    send_msg dev, msg
	    msg = encode_nav row,vers
	    send_msg dev, msg
	  end
	end
	et = ((us - st)/1000000).to_i
	msg = encode_et et
	send_msg dev, msg
	sleep (mindelay) ? mindelay : NORMDELAY
      end
    end
    lindex += 1
  end
end
et = ((us - st)/1000000).to_i
msg = encode_et et
send_msg dev, msg

# fake up a few disarm messages
if lastr
  msg = encode_stats lastr,vers,0
  0.upto(5) do
    send_msg dev, msg
    sleep 0.1
  end
end

send_msg dev, encode_x(disarms[idx-1])
#File.unlink(STDERR_LOG) if File.zero?(STDERR_LOG)
