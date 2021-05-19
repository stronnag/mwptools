gnome = import('gnome')

deps = []
dopts = []
xopts = []

if host_machine.system() == 'linux'
  dopts += 'LINUX'
  deps += dependency('gudev-1.0')
endif

r = run_command('valac', '--api-version')
if r.returncode() != 0
  error('failed to get vala api-version')
endif
vapivers = r.stdout().strip()

if vapivers.version_compare('<0.38')
  error('Vala is obsolete')
endif

# Time value etc
if vapivers.version_compare('<0.40')
  dopts += 'USE_TV1'
endif

if vapivers.version_compare('<0.46')
  dopts += 'USE_TV'
endif

if vapivers.version_compare('>=<0.50')
  dopts += 'USE_URIPARSE'
endif

r = run_command('valac', '--api-version')
if r.returncode() != 0
  error('failed to get vala api-version')
endif
valacvers = r.stdout().strip()

if vapivers.version_compare('<0.51')
  dopts += 'OLDTVI'
else
  glib = dependency('glib-2.0', version: '>=2.68')
  if not glib.found()
    dopts += 'OLDTVI'
  endif
endif

termcap = dependency('ncurses', required: false)

libm = meson.get_compiler('c').find_library('m', required : false)
deps += libm
