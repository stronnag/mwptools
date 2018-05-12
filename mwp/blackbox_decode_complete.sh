_blackbox_decode_complete()
{
  local cur prev OPTS
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  local bbexts='@(TXT|BBL)'

  case $prev in
    '--index')
      COMPREPLY=( $(compgen -W '{1..31}'  -- $cur) )
      return 0
      ;;
    '--unit-amperage')
      COMPREPLY=( $(compgen -W "raw mA A" -- $cur) )
      return 0
      ;;
    '--unit-flags')
      COMPREPLY=( $(compgen -W "raw flags" -- $cur) )
      return 0
      ;;
    '--unit-frame-time')
      COMPREPLY=( $(compgen -W "us s" -- $cur) )
      return 0
      ;;
    '--unit-height')
      COMPREPLY=( $(compgen -W "m cm ft" -- $cur) )
      return 0
      ;;
    '--unit-rotation')
      COMPREPLY=( $(compgen -W "raw deg/s rad/s" -- $cur) )
      return 0
      ;;
    '--unit-acceleration')
      COMPREPLY=( $(compgen -W "raw g m/s2" -- $cur) )
      return 0
      ;;
    '--unit-gps-speed')
      COMPREPLY=( $(compgen -W "mps kph mph" -- $cur) )
      return 0
      ;;
    '--unit-vbat')
      COMPREPLY=( $(compgen -W "raw mV V" -- $cur) )
      return 0
      ;;
  esac
  case $cur in
    -*)
      OPTS="--help
	--index
	--limits
	--stdout
	--unit-amperage
	--unit-flags
	--unit-frame-time
	--unit-height
	--unit-rotation
	--unit-acceleration
	--unit-gps-speed
	--unit-vbat
	--merge-gps
	--simulate-current-meter
	--sim-current-meter-scale
	--sim-current-meter-offset
	--simulate-imu
	--imu-ignore-mag
	--declination
	--declination-dec
	--debug
	--raw"

      COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
      return 0
      ;;
    esac
  _filedir "$bbexts"

}
complete -F _blackbox_decode_complete blackbox_decode
