/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

#include <string.h>
#include <stdlib.h>
#ifdef USE_ESPEAK
#include <espeak/speak_lib.h>

int speech_init(char *voice)
{
    espeak_Initialize(AUDIO_OUTPUT_PLAYBACK, 500, NULL, 0);
    espeak_SetVoiceByName(voice);
    espeak_SetParameter(espeakVOLUME, 200, 0);
    return 0;
}

void speech_say(char *text)
{
    espeak_Synth(text, strlen(text)+1, 0, POS_CHARACTER, 0, espeakCHARS_AUTO, NULL, NULL);
    espeak_Synchronize();
}

void speech_terminate(void)
{
    espeak_Terminate();
}
#elif defined USE_SPEECHD

#include <libspeechd.h>
#include <glib.h>

static SPDConnection *spd;
static GMutex s_mutex;
static GCond s_cond;

void end_of_speech(size_t msg_id, size_t client_id, SPDNotificationType type)
{
    g_cond_signal (&s_cond);
}

int speech_init(char *voice)
{
    int ret=-1;
    spd = spd_open2("mwp", NULL, NULL, SPD_MODE_THREADED,
                   SPD_METHOD_UNIX_SOCKET, 1, NULL);
    if(spd)
    {
      spd_set_language(spd,"en");
      spd_set_synthesis_voice(spd,voice);
      spd_set_volume(spd, -50);
      spd->callback_end = spd->callback_cancel = end_of_speech;
      spd_set_notification_on(spd, SPD_END);
      spd_set_notification_on(spd, SPD_CANCEL);
      ret = 1;
    }
    return ret;
}
void speech_say(char *text)
{
    if(spd)
    {
        g_mutex_lock (&s_mutex);
        spd_say(spd, SPD_TEXT, text);
        g_cond_wait (&s_cond, &s_mutex);
        g_mutex_unlock (&s_mutex);
    }
}
void speech_terminate(void)
{
    if(spd)
        spd_close(spd);
    spd = NULL;
}
#else
int speech_init(char *voice)
{
    return -1;
}
void speech_say(char *text)
{
}
void speech_terminate(void)
{
}
#endif
