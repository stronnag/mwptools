ldirs = ['/usr/lib', '/usr/local/lib']
gnome = import('gnome')

deps = []
dopts = []
xopts = []
mwpv_args = []

deps += dependency('glib-2.0')

if host_machine.system() == 'linux'
  dopts += '--define=LINUX'
  dopts += '--define=UNIX'
  deps += dependency('gudev-1.0')
  deps += dependency('gio-unix-2.0')
endif

if host_machine.system() == 'freebsd'
  dopts += '--define=UNIX'
  dopts += '--define=FREEBSD'
endif

soupdep = dependency('libsoup-3.0')

speak = meson.get_compiler('c').find_library('espeak-ng', dirs: ldirs, required: false).found()
if speak
    xopts += 'USE_ESPEAK_NG'
else
  speak = meson.get_compiler('c').find_library('espeak', dirs: ldirs, required: false).found()
endif

if speak
  xopts += 'USE_ESPEAK'
endif

speak = meson.get_compiler('c').find_library('speechd', dirs: ldirs, required: false).found()
if speak
  xopts += 'USE_SPEECHD'
endif

speak = meson.get_compiler('c').find_library('flite', dirs: ldirs, required: false).found()
if speak
  xopts += 'USE_FLITE'
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
