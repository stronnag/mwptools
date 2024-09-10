
clib_dep = [ dependency('glib-2.0'), dependency('gmodule-2.0')]

paho = meson.get_compiler('c').find_library('paho-mqtt3cs', dirs: ldirs, required: false)

clsrcs = files('btdev.c', 'get_locale_double.c', 'cserial.c', 'mwp_glinfo.c', 'speech_wrapper.c')
if paho.found()
  clsrcs += 'paho_wrapper.c'
  clib_dep += paho
endif

common_inc_dir += [include_directories('.'), include_directories('../common')]

clib_cargs=[]
foreach x : xopts
  clib_cargs += '-D'+x
endforeach

libargs = {
  'sources': clsrcs,
  'include_directories':  common_inc_dir,
  'dependencies': clib_dep,
  'c_args':  clib_cargs,
  'install': true,
  'install_dir': get_option('prefix') / 'lib',
}

if dynalib
 if host_machine.system() == 'linux'
    libargs += {  'version': '1.0.0', 'soversion': '1', }
  endif
  mwpclib = both_libraries('mwpclib', kwargs: libargs)
else
  mwpclib = static_library('mwpclib', kwargs: libargs)
endif

dopts += ['--vapidir', meson.current_source_dir() ]
dopts += ['--pkg', 'mwpfuncs']

install_data('mwpfuncs.h', install_dir: get_option('prefix') / 'include')
install_data('mwpfuncs.vapi', install_dir: get_option('prefix') / 'share/vala/vapi')
