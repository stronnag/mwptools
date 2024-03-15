
glib_dep = dependency('glib-2.0')

libmwpclib = static_library('mwpclib',
  ['btdev.c', 'get_locale_double.c', 'paho_wrapper.c', 'cserial.c', 'mwp_glinfo.c', 'speech_wrapper.c'],
  include_directories :  common_inc_dir,
  dependencies : glib_dep
)
