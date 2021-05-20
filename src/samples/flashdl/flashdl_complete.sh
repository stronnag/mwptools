
_flashdl_complete()
{
  local cur prev OPTS
  local devs
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case $prev in
    '-b'|'--baud')
      COMPREPLY=( $(compgen -W '9600 19200 38400 57600 115200 230400 460800 921600' -- "$cur") )
      return 0
      ;;
    '-d'|'--device')
      devs=$(ls /dev/ttyUSB* /dev/ttyACM* /dev/rfcomm* 2> /dev/null)
      COMPREPLY=( $(compgen -W "$devs" -- $cur) )
      return 0
      ;;
    '-o'|'--output')
      return 0
      ;;
    '-O'|'--output-dir')
      return 0
      ;;
    '-e'|'--erase')
      return 0
      ;;
    '--only-erase')
      return 0
      ;;
    '-i'|'--info')
      return 0
      ;;
    '-t'|'--test')
      return 0
      ;;
    '-h'|'--help')
      return 0
      ;;
  esac
  OPTS="--help
	--baud
	--device
	--output
	--outout-dir
	--erase
	--only-erase
	--info
	--test"

  COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
  return 0
}
complete -F _flashdl_complete flashdl
