#!/usr/bin/env ruby

require 'uart'
require 'io/wait'

module MSP
  MSP_API_VERSION = 1
  MSP_FC_VARIANT  = 2
  MSP_FC_VERSION  = 3
  MSP_BOARD_INFO = 4
  MSP_BUILD_INFO = 5
  MSP_NAME = 10
  MSP2_ADSB_VEHICLE_LIST = 0x2090

  STATE_INIT = 0
  STATE_M = 1
  STATE_DIRN = 2
  STATE_LEN = 3
  STATE_CMD = 4
  STATE_DATA = 5
  STATE_CRC = 6
  STATE_X_HEADER2 = 7
  STATE_X_FLAGS = 8
  STATE_X_ID1 = 9
  STATE_X_ID2 = 10
  STATE_X_LEN1 = 11
  STATE_X_LEN2 = 12
  STATE_X_DATA = 13
  STATE_X_CHECKSUM = 14

  CRCTAB=[
    0x00, 0xd5, 0x7f, 0xaa, 0xfe, 0x2b, 0x81, 0x54,
    0x29, 0xfc, 0x56, 0x83, 0xd7, 0x02, 0xa8, 0x7d,
    0x52, 0x87, 0x2d, 0xf8, 0xac, 0x79, 0xd3, 0x06,
    0x7b, 0xae, 0x04, 0xd1, 0x85, 0x50, 0xfa, 0x2f,
    0xa4, 0x71, 0xdb, 0x0e, 0x5a, 0x8f, 0x25, 0xf0,
    0x8d, 0x58, 0xf2, 0x27, 0x73, 0xa6, 0x0c, 0xd9,
    0xf6, 0x23, 0x89, 0x5c, 0x08, 0xdd, 0x77, 0xa2,
    0xdf, 0x0a, 0xa0, 0x75, 0x21, 0xf4, 0x5e, 0x8b,
    0x9d, 0x48, 0xe2, 0x37, 0x63, 0xb6, 0x1c, 0xc9,
    0xb4, 0x61, 0xcb, 0x1e, 0x4a, 0x9f, 0x35, 0xe0,
    0xcf, 0x1a, 0xb0, 0x65, 0x31, 0xe4, 0x4e, 0x9b,
    0xe6, 0x33, 0x99, 0x4c, 0x18, 0xcd, 0x67, 0xb2,
    0x39, 0xec, 0x46, 0x93, 0xc7, 0x12, 0xb8, 0x6d,
    0x10, 0xc5, 0x6f, 0xba, 0xee, 0x3b, 0x91, 0x44,
    0x6b, 0xbe, 0x14, 0xc1, 0x95, 0x40, 0xea, 0x3f,
    0x42, 0x97, 0x3d, 0xe8, 0xbc, 0x69, 0xc3, 0x16,
    0xef, 0x3a, 0x90, 0x45, 0x11, 0xc4, 0x6e, 0xbb,
    0xc6, 0x13, 0xb9, 0x6c, 0x38, 0xed, 0x47, 0x92,
    0xbd, 0x68, 0xc2, 0x17, 0x43, 0x96, 0x3c, 0xe9,
    0x94, 0x41, 0xeb, 0x3e, 0x6a, 0xbf, 0x15, 0xc0,
    0x4b, 0x9e, 0x34, 0xe1, 0xb5, 0x60, 0xca, 0x1f,
    0x62, 0xb7, 0x1d, 0xc8, 0x9c, 0x49, 0xe3, 0x36,
    0x19, 0xcc, 0x66, 0xb3, 0xe7, 0x32, 0x98, 0x4d,
    0x30, 0xe5, 0x4f, 0x9a, 0xce, 0x1b, 0xb1, 0x64,
    0x72, 0xa7, 0x0d, 0xd8, 0x8c, 0x59, 0xf3, 0x26,
    0x5b, 0x8e, 0x24, 0xf1, 0xa5, 0x70, 0xda, 0x0f,
    0x20, 0xf5, 0x5f, 0x8a, 0xde, 0x0b, 0xa1, 0x74,
    0x09, 0xdc, 0x76, 0xa3, 0xf7, 0x22, 0x88, 0x5d,
    0xd6, 0x03, 0xa9, 0x7c, 0x28, 0xfd, 0x57, 0x82,
    0xff, 0x2a, 0x80, 0x55, 0x01, 0xd4, 0x7e, 0xab,
    0x84, 0x51, 0xfb, 0x2e, 0x7a, 0xaf, 0x05, 0xd0,
    0xad, 0x78, 0xd2, 0x07, 0x53, 0x86, 0x2c, 0xf9]

  @mspv2 = false

  def MSP.crc2_dvb_s2 crc, a
    crc ^= a
    CRCTAB[crc]
  end

  def MSP.init s
    res = msp_ack s, MSP_API_VERSION, nil
    puts "API: #{res[:data][1]}.#{res[:data][2]}"
    @mspv2 = (res[:data][1] == 2)
    res = msp_ack s, MSP_FC_VARIANT, nil
    puts "VARIANT: #{res[:data].pack('c*')}"
    res = msp_ack s, MSP_FC_VERSION, nil
    puts "VERSION: #{res[:data][0]}.#{res[:data][1]}.#{res[:data][2]}"
    res = msp_ack s, MSP_BUILD_INFO, nil
    puts "BUILD: #{res[:data][19..-1].pack('c*')}"
    res = msp_ack s, MSP_BOARD_INFO, nil
    bv = nil
    if res[:len] > 8
      bv = res[:data][9..-1].pack('c*')
    else
      bv = res[:data][0..4].pack('c*')
    end
    puts "BOARD: #{bv}"
    res = msp_ack s, MSP_NAME, nil
    puts "NAME: #{res[:data].pack('c*')}"
  end

  def MSP.msp_read s
    res={cmd: 0, len: 0, ok: false, data:[]}
    mstate = STATE_INIT
    crc = 0
    ccrc = 0
    count = 0
    ok = false
    while true
      if s.wait_readable(1)
        c = s.read(1).bytes[0]
        case mstate
        when STATE_INIT
        if c == '$'.ord
          mstate = STATE_M
        end

        when STATE_M
          if c == 'M'.ord
            mstate = STATE_DIRN
          elsif c == 'X'.ord
            mstate = STATE_X_HEADER2
          else
            mstate = STATE_INIT
          end

        when STATE_DIRN
          if c == '!'.ord
            mstate = STATE_LEN
          elsif c == '>'.ord
            mstate = STATE_LEN
            ok = true;
          else
            mstate = STATE_INIT
          end

        when STATE_X_HEADER2
          if c == '!'.ord
            mstate = STATE_X_FLAGS
          elsif c == '>'.ord
            mstate = STATE_X_FLAGS
            ok = true;
          else
            mstate = STATE_INIT
          end

        when STATE_X_FLAGS
          crc = crc2_dvb_s2(0, c);
          mstate= STATE_X_ID1

        when STATE_X_ID1
          crc = crc2_dvb_s2(crc, c)
          cmd = c
          mstate = STATE_X_ID2

        when STATE_X_ID2
          crc = crc2_dvb_s2(crc, c)
          cmd |= (c << 8)
          mstate = STATE_X_LEN1

        when STATE_X_LEN1
          crc = crc2_dvb_s2(crc, c)
          len = c
          mstate = STATE_X_LEN2

        when STATE_X_LEN2
          crc = crc2_dvb_s2(crc, c)
          len |= (c << 8)
          if len > 0
            mstate = STATE_X_DATA
            count = 0
          else
            mstate = state_X_CHECKSUM
          end
          res[:cmd] = cmd
          res[:len] = len
          res[:ok] = ok

        when STATE_X_DATA
          crc = crc2_dvb_s2(crc, c)
          res[:data] << c
          count += 1
          if count == len
            mstate = STATE_X_CHECKSUM
          end

        when STATE_X_CHECKSUM
          ccrc = c
          if crc != ccrc
            STDERR.puts "CRC error on #{cmd}"
            mstate = STATE_INIT
          else
            return res
          end

        when STATE_LEN
          len = c
          crc = c;
          mstate = STATE_CMD

        when STATE_CMD
          cmd = c
          crc ^= c
          if len == 0
            mstate = STATE_CRC
          else
            res[:cmd] = cmd
            res[:len] = len
            res[:ok] = ok
            mstate = STATE_DATA
            count = 0
          end

        when STATE_DATA
          res[:data] << c
          crc ^= c
          count += 1
          if count == len
            mstate = STATE_CRC
          end

        when STATE_CRC
          ccrc = c
          if crc != ccrc
            STDERR.puts "CRC error on #{cmd}"
            mstate = STATE_INIT
          else
            return res
          end
        end
      else
        STDERR.puts "Serial timeout"
        res[:ok] = false
        break
      end
    end
    res
  end

  def MSP.msp_send s, cmd, payload
    if cmd > 255
      @mspv2 = true
    end
    buf = (@mspv2==true) ? msp2_encode(cmd, payload,true) : msp1_encode(cmd, payload)
    s.write buf
  end

  def MSP.msp_fcsend s, cmd, payload
    buf = msp2_encode(cmd, payload,true)
    s.write buf
  end

  def MSP.msp_ack s,cmd,payload
    msp.send s,cmd,payload
    msp.read s
  end

  def MSP.msp2_encode cmd, buf,fc=false
    blen = buf.nil? ? 0 : buf.size
    sdata=nil
    if fc == false
      sdata = "$X<"
    else
      sdata = "$X>"
    end
    sdata << 0.chr
    sdata << [cmd,blen].pack("SS")
    if blen > 0
      sdata << buf
    end
    crc = 0
    sdata[3..-1].each_byte do |b|
      crc = crc2_dvb_s2 crc, b
    end
    sdata << [crc].pack("c")
    sdata
  end

  def MSP.msp1_encode cmd, buf
    blen = buf.nil? ? 0 : buf.size
    sdata = "$M<"
    sdata << [blen,cmd].pack("cc")
    if blen > 0
      sdata << buf
    end
    crc = 0
    sdata[3..-1].each_byte do |b|
      crc ^= b
    end
    sdata << [crc].pack("c")
    sdata
  end

  def MSP.adsb s,a
    maxvl = a.length
    if maxvl > 10
      maxvl = 10
    end
    b = [maxvl, 9].pack("cc")
    0.upto(maxvl-1) do |i|
      v = a[i]
      bb =  [v[:callsign].ljust(8,' '), v[:icao], v[:lat], v[:lon], v[:alt],
             v[:hdr], v[:tslc], v[:typ], v[:ttl]].pack("Z*Llllsccc")
      b << bb
    end
    msp_fcsend s,MSP2_ADSB_VEHICLE_LIST,b
  end
end
