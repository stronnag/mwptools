
#include <string.h>
#include <stdlib.h>
#include <espeak/speak_lib.h>

void espeak_init(char *voice)
{
    espeak_Initialize(AUDIO_OUTPUT_PLAYBACK, 500, NULL, 0);
    espeak_SetVoiceByName(voice);
}

void espeak_say(char *text)
{
    espeak_Synth(text, strlen(text)+1, 0, POS_CHARACTER, 0, espeakCHARS_AUTO, NULL, NULL);
    espeak_Synchronize();
}

void espeak_terminate(void)
{
    espeak_Terminate();
}
