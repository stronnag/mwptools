gatt_app_src = files('mwp-ble-bridge.vala', 'socket-utils.vala')
gatt_deps = [
  dependency('gio-2.0'),
  dependency('gio-unix-2.0'),
  meson.get_compiler('vala').find_library('posix')
]

gatt_args =''
#if meson.get_compiler('c').get_id() == 'clang'
  gatt_args='-D_XOPEN_SOURCE=600'
#endif
