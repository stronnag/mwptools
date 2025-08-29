add_languages('cpp')

clib_cargs = []
#wcamvsrc = files('wcamv.vala')

wcamldeps = [
  dependency('glib-2.0'),
  meson.get_compiler('c').find_library('ole32'),
  meson.get_compiler('c').find_library('oleaut32'),
  meson.get_compiler('c').find_library('strmiids')
]

wcam_inc_dir = include_directories('.')

dopts += ['--vapidir', meson.current_source_dir() ]
dopts += ['--pkg', 'wcam']

wcamlibargs = {
  'sources': 'wcam.cpp',
  'include_directories':  wcam_inc_dir,
  'dependencies': wcamldeps,
  'c_args':  clib_cargs,
  'install': true,
  'install_dir': get_option('prefix') / 'lib',
}

wcamclib = static_library('wcamlib', kwargs: wcamlibargs)


