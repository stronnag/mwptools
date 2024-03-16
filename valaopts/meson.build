vcargs = [ '-Wno-unused-variable', '-Wno-unused-function', '-Wno-unused-but-set-variable', '-Wno-pointer-sign', '-Wno-deprecated-declarations', '-Wno-unused-value', '-Wno-unused-result' ]

if meson.get_compiler('c').get_id() == 'clang'
  vcargs += [ '-Wno-error=incompatible-function-pointer-types', '-Wno-macro-redefined', '-Wno-tautological-pointer-compare', '-Wno-bitwise-instead-of-logical', '-Wno-void-pointer-to-enum-cast' ]
endif

if meson.get_compiler('c').get_id() == 'gcc'
  vcargs += ['-Wno-incompatible-pointer-types',  '-Wno-address', '-Wno-implicit-function-declaration', '-Wno-discarded-qualifiers', '-Wno-tautological-compare']
endif
