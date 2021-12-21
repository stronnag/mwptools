Flite Text to Speech
====================

## Overview

{{ mwp }} can use the `flite` text to speech engine (as well as **espeak** or **speech-dispatcher**. Flite is enabled if:

* You have the flite development files installed

Flite is available at run-time if:

* The flite version is 2.0 or later.

Unfortunately, it is non-trivial to detect the flite version at build time.

Flite provides reasonable quality voices with low overhead, including some female voices.

## Configuration

Flite is configured using two `gsettings` keys:

| Key | Usage |
| --- | ----- |
| `speech-api` | Defines the speech api to be used, one of `none`, `espeak`, `speechd` or `flite`  |
| `flite-voice` | The voice file to be used. If not specified, the internal `slt` (female) voice is used. The value takes the absolute path name to a voice file, optionally followed by a `,` and a floating point speed factor (see below) |

```
$ gsettings set org.mwptools.planner speech-api flite
$ gsettings set org.mwptools.planner flite-voice-file /home/jrh/.config/mwp/cmu_us_clb.flitevox,0.9
```

## Discussion

### Voice Files

flite can use external voice files that provide better quality than the built-in voices. Your distro may provide these voice files in an optional package, or you can download from http://www.festvox.org, eg. for flite 2.1 http://www.festvox.org/flite/packed/flite-2.1/voices/ (replace 2.1 with 2.0 etc., not all the 2.1 voices may exist for 2.0). The following script will bulk download the non-Indic voices; you can test them out with the `flite` application, or mwp's `ftest` [application](#test)).

```
#!/bin/bash

BASE=http://www.festvox.org/flite/packed/flite-2.1/voices

for V in cmu_us_aew.flitevox cmu_us_ahw.flitevox cmu_us_aup.flitevox \
  cmu_us_awb.flitevox cmu_us_axb.flitevox cmu_us_bdl.flitevox \
  cmu_us_clb.flitevox cmu_us_eey.flitevox cmu_us_fem.flitevox \
  cmu_us_gka.flitevox cmu_us_jmk.flitevox cmu_us_ksp.flitevox \
  cmu_us_ljm.flitevox cmu_us_lnh.flitevox cmu_us_rms.flitevox \
  cmu_us_rxr.flitevox cmu_us_slp.flitevox cmu_us_slt.flitevox
do
  wget -P . $BASE/$V
done
```

### Replay Speed

The default replay speed for some flite voices is rather slow. The optional rate setting in the gsettings `flite-voice-file` key may be used to increase the rate.

## Test

`mwptools/samples/flite` provides a test programme for assessing flite voices.

```
$ cd  mwptools/samples/flite
$ make
$ ./ftest < mwp.txt # speak mwp like phrases using default voice
$ ./ftest cmu_us_clb.flitevox,0.9 < mwp.txt # speak mwp like phrases using external voice file, with relative rate (0.9)
```

Note: this test programme will work with flite 1.x; though you can only use the default 'kal' voice (you cannot load 'better' voices).
