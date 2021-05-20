clisrcs = files('cliterm.vala')

clideps = [deps,
	   dependency('gio-2.0'),
	   dependency('vte-2.91'),
           meson.get_compiler('vala').find_library('posix'),
           meson.get_compiler('vala').find_library('linux'),
	  ]

cli_v_args = ['--vapidir', vapi_dir, '--pkg', 'mwpfuncs']
common_inc_dir += include_directories('.')
