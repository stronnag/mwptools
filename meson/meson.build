gnome = import('gnome')

deps = []
dopts = []
xopts = []

if host_machine.system() == 'linux'
  dopts += '--define=LINUX'
  dopts += '--define=UNIX'
  deps += dependency('gudev-1.0')
  deps += dependency('gio-unix-2.0')
endif

if host_machine.system() == 'freebsd'
  dopts += '--define=UNIX'
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

glib = dependency('glib-2.0', version: '>=2.66', required: false)
if glib.found() and vapivers.version_compare('>0.48')
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

r = run_command('pkg-config', '--modversion', 'champlain-0.12',  check: true)
if r.returncode() != 0
  error('failed to get champlain version')
endif
champvers = r.stdout().strip()

if champvers.version_compare('<0.12.21')
  soupdep =  dependency('libsoup-2.4')
  dopts += '--define=COLDSOUP'
else
  soupdep =  dependency('libsoup-3.0')
endif

termcap = dependency('ncurses', required: false)

libm = meson.get_compiler('c').find_library('m', required : false)
deps += libm

gotrim = ''
gook = false
golang = find_program('go', required: false)
if golang.found()
  r = run_command('go', 'version', check: true)
  if r.returncode() != 0
    error('failed to get go version')
  else
    govers = r.stdout().strip()
    go1 = govers.split()
    go2 = go1[2].split('.')
    if go2.length() > 1
      gotrim = '-trimpath'
      gminor = go2[1].to_int()
      if gminor < 17
        message('Go compiler is too old, consider installing the latest vendor compiler')
      else
        gook = true
      endif
    endif
  endif
endif
