
clib_dep = [ dependency('glib-2.0'), dependency('gmodule-2.0')]


ldirs = ['/usr/lib', '/usr/local/lib']
paho = meson.get_compiler('c').find_library('paho-mqtt3cs', dirs: ldirs, required: false)

clsrcs = files('btdev.c', 'get_locale_double.c', 'cserial.c', 'mwp_glinfo.c', 'speech_wrapper.c')
if paho.found()
  clsrcs += 'paho_wrapper.c'
  clib_dep += paho
endif

common_inc_dir += [include_directories('.'), include_directories('../common')]

libargs = {
  'sources': clsrcs,
  'include_directories':  common_inc_dir,
  'dependencies': clib_dep,
  'install': true,
  'install_dir': [get_option('prefix') / 'lib'],
}

if dynalib
  mwpclib = both_libraries('mwpclib', kwargs: libargs)
else
  mwpclib = static_library('mwpclib', kwargs: libargs)
endif
