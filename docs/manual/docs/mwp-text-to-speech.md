Text to Speech
==============

## Overview

On all platforms, an external `TTS` (Text to speech) application may be defined by the `--voice-command` option. Alternately, on POSIX platforms, a speech library may be dynamically loaded at run time. This requires the desired speech library to have been available when mwp was compiled.

### Built-in libraries

* Espeak / Espeak-ng
* Speech Dispatcher
* Flite

None of these provide very good speech synthesis

### External Commands

You can use an external command on all platforms (it is the only option on Windows). Any external speech command should:

* Read lines of text to be spoken from `stdin` (standard input)
* Directly output the synthesised speech
* Only require invoking _once_, reading `stdin` for new text until it is closed.

#### External command usage

The simplest way is to add a `--voice-command` line to your  [cmdopts](mwp-Configuration.md#cmdopts) file.

Examples:

```
# Espeak-ng
--voice-command="espeak-ng"
```

```
# Speech Dispatcher
--voice-command="spd-say -t female2 -e"
```

```
# piper-tts
# Choose your model, I have like the Scottish lady ...
#VMODEL=/usr/share/piper-voices/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx
#VMODEL=/usr/share/piper-voices/en/en_GB/aru/medium/en_GB-aru-medium.onnx
VMODEL=/usr/share/piper-voices/en/en_GB/alba/medium/en_GB-alba-medium.onnx
--voice-command="sh -c \"piper-tts -q --model $VMODEL --output-raw | aplay -q -r 22050 -f S16_LE -t raw -\""
```

In the `piper-tts` example, (by far the best TTS for Linux), the voice model file is defined by an environment variable `VMODEL` which is evaluated by mwp before the voice command is invoked, making it easy to test out different voices.


### Flite specifics

{{ mwp }} can use the `flite` text to speech engine directly (as well as **espeak** or **speech-dispatcher**. Flite is enabled if:

* You have the flite development files installed

Flite is available at run-time if:

* The flite version is 2.0 or later.

Unfortunately, it is non-trivial to detect the flite version at mwp build time.

Flite provides reasonable quality voices with low overhead, including some female voices.

## Configuration

Flite is configured using two `gsettings` keys:

| Key | Usage |
| --- | ----- |
| `speech-api` | Defines the speech API to be used, one of `none`, `espeak`, `speechd` or `flite`  |
| `flite-voice` | The voice file to be used. If not specified, the internal `slt` (female) voice is used. The value takes the absolute path name to a voice file, optionally followed by a `,` and a floating point speed factor (see below) |

    $ gsettings set org.stronnag.mwp speech-api flite
    $ gsettings set org.stronnag.mwp flite-voice-file /home/jrh/.config/mwp/cmu_us_clb.flitevox,0.9

### Flite Discussion

#### Voice Files

flite can use external voice files that provide better quality than the built-in voices. Your distro may provide these voice files in an optional package, or you can download from http://www.festvox.org, e.g. for flite 2.1 http://www.festvox.org/flite/packed/flite-2.1/voices/ (replace 2.1 with 2.0 etc., not all the 2.1 voices may exist for 2.0). The following script will bulk download the non-Indic voices; you can test them out with the `flite` application.

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

#### Replay Speed

The default replay speed for some flite voices is rather slow. The optional rate setting in the gsettings `flite-voice-file` key may be used to increase the rate.
