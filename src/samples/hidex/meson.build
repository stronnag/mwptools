hidclisrcs = files('mwp-hid-cli.vala')
hidtestsrcs = files('mwp-hid-test.vala')
hidsrvsrcs =  files('mwp-hid-server.vala', 'hid-reader.vala')

if host_machine.system() != 'windows'
  giodep = dependency('gio-unix-2.0')
else
  giodep = dependency('gio-windows-2.0')
endif

hidtestdeps = [deps, dependency('sdl2') ]

hidsrvdeps = [ hidtestdeps, giodep, dependency('gio-2.0'), meson.get_compiler('vala').find_library('posix'), meson.get_compiler('c').find_library('m'), ]

hidclideps = [ dependency('gio-2.0'), dependency('readline'), meson.get_compiler('c').find_library('readline', dirs: libdir) ]
