#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# MIT licence

include Math

module Poscalc
  RAD = 0.017453292

  def Poscalc.d2r d
    d*RAD
  end

  def Poscalc.r2d r
    r/RAD
  end

  def Poscalc.nm2r nm
    (PI/(180*60))*nm
  end

  def Poscalc.r2nm r
    ((180*60)/PI)*r
  end

  def Poscalc.csedist lat1,lon1,lat2,lon2
    lat1 = d2r(lat1)
    lon1 = d2r(lon1)
    lat2 = d2r(lat2)
    lon2 = d2r(lon2)
    d=2.0*asin(sqrt((sin((lat1-lat2)/2.0))**2 +
		    cos(lat1)*cos(lat2)*(sin((lon2-lon1)/2.0))**2))
    d = r2nm(d)
    cse =  (atan2(sin(lon2-lon1)*cos(lat2),
		 cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1))) % (2.0*PI)
    cse = r2d(cse)
    [cse,d]
  end

    def Poscalc.posit lat1, lon1, cse, dist
    tc = d2r(cse)
    rlat1= d2r(lat1)
    rdist = nm2r(dist)
    lat = asin(sin(rlat1)*cos(rdist)+cos(rlat1)* sin(rdist)*cos(tc))
    dlon = atan2(sin(tc)*sin(rdist)*cos(rlat1),
                 cos(rdist)-sin(rlat1)*sin(lat))
    long = ((PI + d2r(lon1) + dlon) % (2 * PI)) - PI
    lat=r2d(lat)
    long = r2d(long)
    [lat, long]
  end

end

if __FILE__ == $0
  lat1 = ARGV[0].to_f
  lon1 = ARGV[1].to_f
  lat2 = ARGV[2].to_f
  lon2 = ARGV[3].to_f
  c,d =  Poscalc.csedist lat1,lon1,lat2,lon2
  puts c
end
