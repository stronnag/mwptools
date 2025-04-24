subdir('cliterm')
subdir('ublox-test')
subdir('flashdl')
if with_hid
  subdir('hidex')
endif

install_data(
  'flash.sh',
  rename:  'fcflash',
  install_dir: 'bin', install_mode: 'rwxr-xr-x'
)
