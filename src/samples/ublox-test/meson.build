
ublxresources = gnome.compile_resources(
    'ublx-resources',
    'ublox.gresources.xml',
    source_dir: '.',
    c_name: 'ublx'
)

ublxcsrcs = files('ublox-cli.vala', 'ublox-io.vala')
ublxgsrcs = files('ublox-test.vala', 'ublox-io.vala')

ublxgsrcs += ublxresources

ublxgdeps =  [deps,
	      dependency('gio-2.0'),
	      dependency('gtk+-3.0'),
	      dependency('atk'),
	      dependency('clutter-1.0'),
	      dependency('champlain-gtk-0.12'),
	      dependency('champlain-0.12'),
	      dependency('clutter-gtk-1.0'),
	      soupdep,
	      meson.get_compiler('vala').find_library('posix'),
	     ]

ublxcdeps =  [deps,
	      dependency('gio-2.0'),
	      meson.get_compiler('vala').find_library('posix')
	     ]

ublx_v_args = ['--vapidir', vapi_dir, '--pkg', 'mwpfuncs',
	       '--vapidir', meson.current_source_dir(), '--pkg', 'ublox'
	      ]
common_inc_dir += include_directories('.')
