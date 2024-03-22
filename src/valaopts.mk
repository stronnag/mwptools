VALAC = valac

OPTS=--enable-deprecated -X -Wno-deprecated-declarations -X -Wno-unused-variable -X -Wno-unused-function -X -Wno-unused-but-set-variable -X -Wno-pointer-sign -X -Wno-deprecated-declarations -X -Wno-unused-value -X -Wno-format

ifeq ($(CC),clang)
  USE_CLANG=1
else
 ifeq ($(XOS),FreeBSD)
   USE_CLANG=1
 endif
endif

ifeq ($(USE_CLANG),1)
  OPTS += -X -Wno-error=incompatible-function-pointer-types -X -Wno-macro-redefined -X -Wno-tautological-pointer-compare -X -Wno-bitwise-instead-of-logical -X -Wno-void-pointer-to-enum-cast -X -Wno-incompatible-pointer-types-discards-qualifiers
else
  OPTS += -X -Wno-incompatible-pointer-types -X -Wno-address -X -Wno-implicit-function-declaration -X -Wno-discarded-qualifiers -X -Wno-tautological-compare
endif
