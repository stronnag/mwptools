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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <glib.h>
#include <gmodule.h>
static GModule *handle;

#ifdef USE_ESPEAK
#include <espeak/speak_lib.h>

typedef int (*espeak_synth_t)(const void *, size_t, unsigned int, espeak_POSITION_TYPE, unsigned int, unsigned int, unsigned int*, void*);
typedef void (*espeak_synchronize_t)(void);
typedef int (*espeak_initialize_t)(espeak_AUDIO_OUTPUT, int, const char*, int);
typedef void (*espeak_setvoicebyname_t)(char *);

static espeak_synth_t ess;
static espeak_synchronize_t esh;

static int ep_init(char *voice)
{
    int res = -1;
    gchar * modname;
    modname = g_module_build_path(NULL, "espeak");
    if(modname)
    {
        handle = g_module_open(modname, G_MODULE_BIND_LAZY);
        if (handle)
        {
            espeak_initialize_t esi;
            if(g_module_symbol(handle, "espeak_Initialize", (gpointer *)&esi))
                res = (*esi)(AUDIO_OUTPUT_PLAYBACK,0, NULL, 0);
            if(res != -1)
            {
                espeak_setvoicebyname_t esv;
                if(g_module_symbol(handle, "espeak_SetVoiceByName",(gpointer *)&esv))
                    (*esv)(voice);
                if(g_module_symbol(handle, "espeak_Synth",(gpointer *)&ess) &&
                   g_module_symbol(handle, "espeak_Synchronize",(gpointer *)&esh))
                    res = 0;
            }
        }
        g_free(modname);
    }
    return res;
}

static void ep_say(char *text)
{
    (*ess)(text, strlen(text)+1, 0, POS_CHARACTER, 0, espeakCHARS_AUTO, NULL, NULL);
    (*esh)();
}
#endif

#ifdef USE_SPEECHD
#include <speech-dispatcher/libspeechd.h>

static SPDConnection *spd;
static GMutex s_mutex;
static GCond s_cond;
typedef SPDConnection *(*spd_open2_t)(const char *, const char *,
                                    const char *, SPDConnectionMode,
                                    SPDConnectionAddress *, int,
                                    char **);
typedef int (*spd_say_t)(SPDConnection *, SPDPriority, const char *);
typedef int (*spd_set_synthesis_voice_t)(SPDConnection *, const char *);
typedef int (*spd_set_language_t)(SPDConnection *, const char *);
typedef int (*spd_set_volume_t)(SPDConnection *, signed int);
typedef int (*spd_set_notification_on_t)(SPDConnection *, SPDNotification);

static void end_of_speech(size_t msg_id, size_t client_id, SPDNotificationType type)
{
    g_cond_signal (&s_cond);
}

static  spd_say_t ssay;

static int sd_init(char *voice)
{
    int ret=-1;
    gchar * modname;
    modname = g_module_build_path(NULL, "speechd");
    if(modname)
    {
        handle = g_module_open(modname, G_MODULE_BIND_LAZY);
        if (handle)
        {
            spd_open2_t spdo2;
            if(g_module_symbol(handle,"spd_open2", (gpointer*)&spdo2))
                spd = (*spdo2)("mwp", NULL, NULL, SPD_MODE_THREADED, NULL, 1, NULL);
            if(spd)
            {
                spd_set_synthesis_voice_t sssv;
                spd_set_language_t ssl;
                spd_set_volume_t ssv;
                spd_set_notification_on_t ssno;

                if(g_module_symbol(handle, "spd_set_language",(gpointer*)&ssl))
                    (*ssl)(spd,"en");
                if (g_module_symbol(handle, "spd_set_synthesis_voice",(gpointer*)&sssv))
                    (*sssv)(spd,voice);
                if(g_module_symbol(handle, "spd_set_volume",(gpointer*)&ssv))
                    (*ssv)(spd, -50);
                if(g_module_symbol(handle, "spd_set_notification_on",(gpointer*)&ssno))
                {
                    spd->callback_end = spd->callback_cancel = end_of_speech;
                    (*ssno)(spd, SPD_END);
                    (*ssno)(spd, SPD_CANCEL);
                }
                if(g_module_symbol(handle, "spd_say",(gpointer*)&ssay))
                    ret = 1;
            }
        }
        g_free(modname);
    }
    return ret;
}
static void sd_say(char *text)
{
    if(spd)
    {
        g_mutex_lock (&s_mutex);
        (*ssay)(spd, SPD_TEXT, text);
        g_cond_wait (&s_cond, &s_mutex);
        g_mutex_unlock (&s_mutex);
    }
}
#endif

static int ss_init(char *v)
{
    fprintf(stderr, "null speech init %s\n", v);
    return -1;
}

static void ss_say(char *t)
{
    fprintf(stderr, "null speech say %s\n", t);
}

static int (*_speech_init)(char *) = ss_init;
static void (*_speech_say)(char *) = ss_say;

guchar get_speech_api_mask()
{
    guchar  api_mask = 0;
#ifdef USE_ESPEAK
    api_mask |= 1;
#endif
#ifdef USE_SPEECHD
    api_mask |= 2;
#endif
    return api_mask;
}

void speech_set_api(guchar api)
{
#ifdef USE_ESPEAK
    if(api == 1)
    {
        _speech_init = ep_init;
        _speech_say = ep_say;
        return;
    }
#endif
#ifdef USE_SPEECHD
    if(api == 2)
    {
        _speech_init = sd_init;
        _speech_say = sd_say;
        return;
    }
#endif
}

int speech_init(char *voice)
{
    int res = (*_speech_init)(voice);
    if(res == -1)
         _speech_say = ss_say;
    return res;
}

void speech_say(char *text)
{
    (*_speech_say)(text);
}
