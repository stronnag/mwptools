gnome = import('gnome')

deps = []
dopts = []
xopts = []

if host_machine.system() == 'linux'
  dopts += '--define=LINUX'
  deps += dependency('gudev-1.0')
endif

r = run_command('valac', '--api-version', check: true)
if r.returncode() != 0
  error('failed to get vala api-version')
endif
vapivers = r.stdout().strip()

if vapivers.version_compare('<0.38')
  error('Vala is obsolete')
endif

# Time value etc
if vapivers.version_compare('<0.40')
  dopts += '--define=USE_TV1'
endif

if vapivers.version_compare('<0.46')
  dopts += '--define=USE_TV'
endif

glib = dependency('glib-2.0', version: '>=2.66')
if glib.found()
  dopts += '--define=USE_URIPARSE'
else
  message('using fallback URI parser')
endif

if vapivers.version_compare('<0.51')
  dopts += '--define=OLDTVI'
else
  glib = dependency('glib-2.0', version: '>=2.68')
  if not glib.found()
    dopts += '--define=OLDTVI'
  endif
endif

termcap = dependency('ncurses', required: false)

libm = meson.get_compiler('c').find_library('m', required : false)
deps += libm

gotrim = ''
gobuild = ''
golang = find_program('go')
if golang.found()
  gobuild = meson.current_source_dir() / 'gobuild.sh'
  r = run_command('go', 'version', check: true)
  if r.returncode() != 0
  error('failed to get go version')
  else
    govers = r.stdout().strip()
    go1 = govers.split()
    go2 = go1[2].split('.')
    if go2.length() > 1
      gminor = go2[1].to_int()
      if gminor > 12
	gotrim = '-trimpath'
      endif
    endif
  endif
endif
