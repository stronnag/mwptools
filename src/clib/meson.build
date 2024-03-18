
glib_dep = dependency('glib-2.0')

ldirs = ['/usr/lib', '/usr/local/lib']
paho = meson.get_compiler('c').find_library('paho-mqtt3cs', dirs: ldirs, required: false)

clsrcs = files('btdev.c', 'get_locale_double.c', 'cserial.c', 'mwp_glinfo.c', 'speech_wrapper.c')
if paho.found()
  clsrcs += 'paho_wrapper.c'
endif


libmwpclib = static_library('mwpclib',
                            clsrcs,
                            include_directories :  common_inc_dir,
                            dependencies : glib_dep,
                            install: true
                           )
