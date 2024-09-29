# auto-declination

Test for INAV's auto-declination.

Requires that you copy the INAV declination generator to this directory/

```
$ ln -sf $INAV_DIR/src/main/navigation/navigation_declination_gen.c ./
$ gcc -Wall -O2 -o auto-decl auto-decl.c -lm
```

Usage: `auto-decl lat lon`, e.g.

```
$ ./auto-decl 50.91 -1.535
dec = 0.43 for 50.910000 -1.535000
```
