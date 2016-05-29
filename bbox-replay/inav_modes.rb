#!/usr/bin/ruby

# Extract heading & gps_course for analysis
# MIT licence

require 'csv'
require 'optparse'

STATES = %w/NAV_STATE_UNDEFINED
  NAV_STATE_IDLE
  NAV_STATE_ALTHOLD_INITIALIZE
  NAV_STATE_ALTHOLD_IN_PROGRESS
  NAV_STATE_POSHOLD_2D_INITIALIZE
  NAV_STATE_POSHOLD_2D_IN_PROGRESS
  NAV_STATE_POSHOLD_3D_INITIALIZE
  NAV_STATE_POSHOLD_3D_IN_PROGRESS
  NAV_STATE_RTH_INITIALIZE
  NAV_STATE_RTH_2D_INITIALIZE
  NAV_STATE_RTH_2D_HEAD_HOME
  NAV_STATE_RTH_2D_GPS_FAILING
  NAV_STATE_RTH_2D_FINISHING
  NAV_STATE_RTH_2D_FINISHED
  NAV_STATE_RTH_3D_INITIALIZE
  NAV_STATE_RTH_3D_CLIMB_TO_SAFE_ALT
  NAV_STATE_RTH_3D_HEAD_HOME
  NAV_STATE_RTH_3D_GPS_FAILING
  NAV_STATE_RTH_3D_HOVER_PRIOR_TO_LANDING
  NAV_STATE_RTH_3D_LANDING
  NAV_STATE_RTH_3D_FINISHING
  NAV_STATE_RTH_3D_FINISHED
  NAV_STATE_WAYPOINT_INITIALIZE
  NAV_STATE_WAYPOINT_PRE_ACTION
  NAV_STATE_WAYPOINT_IN_PROGRESS
  NAV_STATE_WAYPOINT_REACHED
  NAV_STATE_WAYPOINT_FINISHED
  NAV_STATE_EMERGENCY_LANDING_INITIALIZE
  NAV_STATE_EMERGENCY_LANDING_IN_PROGRESS
  NAV_STATE_EMERGENCY_LANDING_FINISHED/

idx = 1

ARGV.options do |opt|
  opt.banner = "#{File.basename($0)} [options] [file]"
  opt.on('-i','--index=IDX'){|o|idx=o}
  opt.on('-?', "--help", "Show this message") {puts opt.to_s; exit}
  begin
    opt.parse!
  rescue
    puts opt ; exit
  end
end

bbox = (ARGV[0]|| abort('no BBOX log'))
cmd = "blackbox_decode"
cmd << " --index #{idx}"
cmd << " --stdout"
cmd << " " << bbox
IO.popen(cmd,'r') do |p|
  csv = CSV.new(p, :col_sep => ",",
		:headers => :true,
		:header_converters =>
		->(f) {f.strip.downcase.gsub(' ','_').gsub(/\W+/,'').to_sym},
		:return_headers => true)
  hdrs = csv.shift
  st = nil
  nstate = -1

  csv.each do |c|
    ts = c[:time_us].to_f / 1000000
    st = ts if st.nil?
    xts  = ts - st
    if c[:navstate].to_i != nstate
      nstate = c[:navstate].to_i
      puts ["%6.1f" % ts, "(%6.1f)" % xts, STATES[nstate]].join("\t")
    end
  end
end
