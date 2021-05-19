fcsrcs = files('fc-get.vala')
fcdeps = [deps,
	   dependency('gio-2.0'),
	   dependency('vte-2.91'),
           meson.get_compiler('vala').find_library('posix'),
           meson.get_compiler('vala').find_library('linux'),
	  ]

fc_v_args = ['--vapidir', vapi_dir, '--pkg', 'mwpfuncs']

termcap = dependency('ncurses', required: false)
if termcap.found()
  fcdeps += meson.get_compiler('c').find_library('ncurses')
  fc_v_args += ['-D', 'USE_TERMCAP']
endif
