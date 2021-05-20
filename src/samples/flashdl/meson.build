fdlsrcs = files('flashdl.vala')
fdldeps = [deps,
	   dependency('gio-2.0'),
           meson.get_compiler('vala').find_library('posix'),
           meson.get_compiler('vala').find_library('linux'),
	  ]

fdl_v_args = ['--vapidir', vapi_dir, '--pkg', 'mwpfuncs']
if termcap.found()
  fdldeps += meson.get_compiler('c').find_library('ncurses')
  fdl_v_args += ['-D', 'USE_TERMCAP']
endif
