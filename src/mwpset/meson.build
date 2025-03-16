vapi_dir = meson.current_source_dir()

mwpsetargs = ['--gresourcesdir=data/',  '--vapidir', vapi_dir, '--pkg', 'mwpset' ]

if host_machine.system() == 'darwin'
  mwpsetargs += '--define=DARWIN'
endif

mwpsetdeps = [
  dependency('gtk4'),
  dependency('gio-2.0'),
  dependency('libxml-2.0'),
  dependency ('libadwaita-1', version: '>= 1.4')
]

mwpsetsrc = files('mwpset.vala', 'setreader.vala', 'mwpsetedit.vala', 'filechooser.vala')
