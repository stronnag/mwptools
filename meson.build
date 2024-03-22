project('mwptools', 'c', 'vala', version : '7.057.554', meson_version : '>= 0.60')

# vala / clang16 workaround

nogo = get_option('nogo')
force_s = get_option('force-static')
force_d = get_option('force-dynamic')

dynalib = false
if force_d
  dynalib = true
elif force_s
  dynalib = false
else
  dynalib = build_machine.system() == 'linux'
endif

with_gatt = true
if build_machine.system() != 'linux'
  with_gatt = false
endif

conf_data = configuration_data()
conf_data.set('version', meson.project_version())
configure_file(
  input : 'src/common/mwp-config.h.in',
  output : 'mwp-config.h',
  configuration : conf_data
)

configuration_inc = []
common_inc_dir = []

subdir('valaopts')
subdir('meson')
subdir('src/clib')
subdir('src/common')
subdir('src/mwp')
subdir('src/fc-cli')
subdir('src/qproxy')
subdir('src/samples/')
subdir('src/mwp-ble-bridge')
subdir('docs')

exargs = {
  'sources': [mwpsrcs, mwpcommon, mwpvers_h],
  'dependencies': [mwpdeps ],
  'link_with': [mwpclib, libmwpvers, mwpvlib ],
  'include_directories': [common_inc_dir, configuration_inc],
  'vala_args': [dopts, mwp_v_args ],
  'c_args': [mwp_c_args, dev_args, vcargs ],
  'install' : true,
}
if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('mwp', kwargs: exargs)

exargs = {
  'sources': [clisrcs ],
  'dependencies': [ clideps ],
  'include_directories': common_inc_dir,
  'link_with': [ mwpclib, mwpvlib ],
  'vala_args': [dopts, cli_v_args ],
  'c_args': [dev_args, cli_args, vcargs ],
  'install': true,
}

if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('cliterm', kwargs: exargs)

executable('bproxy',
           sources: bproxsrc,
           dependencies: [ proxdeps ],
	   vala_args : dopts,
           c_args: vcargs,
           install : true)

exargs = {
  'sources': [fcsrcs, fccommon ],
  'dependencies': [ fcdeps ],
  'include_directories': common_inc_dir,
  'vala_args': [dopts, fc_v_args ],
  'c_args': [dev_args, vcargs],
  'link_with': [mwpclib, mwpvlib],
  'install': true,
}
if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('fc-get', kwargs: exargs)


exargs = {
  'sources': [ ublxgsrcs, ublxguisrc ],
  'dependencies': ublxgdeps,
  'include_directories' : common_inc_dir,
  'vala_args': [dopts, ublx_v_args],
  'c_args': vcargs,
  'link_with': [mwpclib, mwpvlib],
  'install':false,
  'build_by_default': false,
}
if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('ublox-geo', kwargs: exargs)

exargs = {
  'sources': ublxcsrcs,
  'dependencies': ublxcdeps,
  'include_directories': common_inc_dir,
  'vala_args': [dopts, ublx_v_args],
  'c_args': vcargs,
  'link_with': [mwpclib, mwpvlib],
  'install': false,
  'build_by_default': false,
}
if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('ublox-cli', kwargs: exargs)

exargs = {
  'sources': [apsrcs, apuisrcs, apcommon],
  'dependencies': [ apdeps ],
  'include_directories': common_inc_dir,
  'vala_args': [dopts, ap_v_args],
  'c_args': vcargs,
  'link_with': [mwpclib, mwpvlib],
  'install': true,
}
if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('mwp-area-planner', kwargs: exargs)

exargs = {
  'sources': [fdlsrcs, fccommon ],
  'dependencies': fdldeps,
  'include_directories' : common_inc_dir,
  'vala_args': [dopts, fdl_v_args ],
  'c_args': [dev_args, vcargs],
  'link_with': [mwpclib,mwpvlib],
  'build_by_default': false,
  'install': false,
}
if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('flashdl', kwargs: exargs)

exargs = {
  'sources': proxsrc,
           'dependencies': [ proxdeps ],
	   'vala_args': dopts,
           'c_args': vcargs,
	   'link_with': [mwpclib, mwpvlib],
           'build_by_default': false,
           'install': false,
}
if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
endif
executable('gmproxy', kwargs: exargs)

if with_gatt
  exargs = {
    'sources': gatt_app_src,
    'dependencies': gatt_deps,
    'vala_args': dopts,
    'c_args': [vcargs, gatt_args],
    'link_with': [ mwpvlib],
    'include_directories': common_inc_dir,
    'build_by_default': true,
    'install' : true,
  }
  if dynalib
    exargs += { 'install_rpath': '$ORIGIN/../lib',}
  endif
  executable('mwp-ble-bridge', kwargs: exargs)
endif

subdir('src/bbox-replay')

if nogo == false and gook == true and gotrim != ''
  subdir('pkg/geo')
  subdir('cmd/mwp-plot-elevations')
  mpe = custom_target(
    'mwp-plot-elevations',
    output: 'mwp-plot-elevations',
    input: [mpe_files, geo_files],
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s', mpe_dir ],
    build_by_default: true,
    install: true,
    install_dir: 'bin')

  subdir('cmd/flashgo')
  fgo = custom_target(
    'flashgo',
    output: 'flashgo',
    input: [fgo_files],
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  fgo_dir ],
    build_by_default: true,
    install: true,
    install_dir: 'bin')

  subdir('cmd/mwp-log-replay')
  log_replay = custom_target(
    'mwp-log-replay',
    output: 'mwp-log-replay',
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  mlr_dir ],
    build_by_default: true,
    input: mlr_files,
    install: true,
    install_dir: 'bin')

  subdir('cmd/mwp-serial-cap')
  serial_cap = custom_target(
    'mwp-serial-cap',
    output: 'mwp-serial-cap',
    command: [ golang, 'build', gotrim, '-o', '@OUTPUT@', '-ldflags', '-w -s',  msc_dir ],
    build_by_default: true,
    input: msc_files,
    install: true,
    install_dir: 'bin')
endif

meson.add_install_script('meson/post_install.sh')
if meson.version().version_compare('>= 0.59')
  gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true
  )
else
 meson.add_install_script('meson/legacy_post_install.sh')
endif
