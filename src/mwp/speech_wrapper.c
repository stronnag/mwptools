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

#define _DEFAULT_SOURCE

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <glib.h>
#include <gmodule.h>

#define API_NONE 0
#define API_ESPEAK 1
#define API_SPEECHD 2
#define API_FLITE 3

extern void mwp_log_message(const gchar *format, ...);
#if defined(USE_ESPEAK) || defined(USE_SPEECHD) || defined(USE_FLITE)

static GModule *handle;

static inline gchar *m_module_build_path(const gchar *dir, const gchar *name) {
// Once GLIB actually documents the replacement, the pragmas can be removed
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
  return g_module_build_path(dir, name);
#pragma GCC diagnostic pop
}

#ifdef USE_ESPEAK
#ifdef USE_ESPEAK_NG
#include <espeak-ng/speak_lib.h>
#else
#include <espeak/speak_lib.h>
#endif

typedef int (*espeak_synth_t)(const void *, size_t, unsigned int, espeak_POSITION_TYPE, unsigned int, unsigned int,
                              unsigned int *, void *);
typedef void (*espeak_synchronize_t)(void);
typedef int (*espeak_initialize_t)(espeak_AUDIO_OUTPUT, int, const char *, int);
typedef void (*espeak_setvoicebyname_t)(char *);

static espeak_synth_t ess;
static espeak_synchronize_t esh;

static int ep_init(char *voice) {
  int res = API_NONE;
  gchar *modname = NULL;

#ifdef USE_ESPEAK_NG
  modname = m_module_build_path(NULL, "espeak-ng");
#else
  modname = m_module_build_path(NULL, "espeak");
#endif
  if (modname) {
    handle = g_module_open(modname, G_MODULE_BIND_LAZY);
    if (handle) {
      espeak_initialize_t esi;
      if (g_module_symbol(handle, "espeak_Initialize", (gpointer *)&esi))
        res = (*esi)(AUDIO_OUTPUT_PLAYBACK, 0, NULL, 0);
      if (res != -1) {
        espeak_setvoicebyname_t esv;
        if (g_module_symbol(handle, "espeak_SetVoiceByName", (gpointer *)&esv))
          (*esv)(voice);
        if (g_module_symbol(handle, "espeak_Synth", (gpointer *)&ess) &&
            g_module_symbol(handle, "espeak_Synchronize", (gpointer *)&esh))
          res = API_ESPEAK;
      }
    }
    g_free(modname);
  }
  return res;
}

static void ep_say(char *text) {
  (*ess)(text, strlen(text) + 1, 0, POS_CHARACTER, 0, espeakCHARS_AUTO, NULL, NULL);
  (*esh)();
}
#endif

#ifdef USE_SPEECHD
#include <speech-dispatcher/libspeechd.h>

static SPDConnection *spd;
static GMutex s_mutex;
static GCond s_cond;
typedef SPDConnection *(*spd_open2_t)(const char *, const char *, const char *, SPDConnectionMode, SPDConnectionAddress *, int,
                                      char **);
typedef int (*spd_say_t)(SPDConnection *, SPDPriority, const char *);
typedef int (*spd_set_synthesis_voice_t)(SPDConnection *, const char *);
typedef int (*spd_set_language_t)(SPDConnection *, const char *);
typedef int (*spd_set_volume_t)(SPDConnection *, signed int);
typedef int (*spd_set_notification_on_t)(SPDConnection *, SPDNotification);
typedef int (*spd_set_voice_type_t)(SPDConnection *n, SPDVoiceType);
typedef void (*spd_close_t)(SPDConnection *);

static void end_of_speech(size_t msg_id, size_t client_id, SPDNotificationType type) { g_cond_signal(&s_cond); }

static spd_say_t ssay;

static int sd_init(char *voice) {
  int ret = API_NONE;
  gchar *modname;
  modname = m_module_build_path(NULL, "speechd");
  if (modname) {
    handle = g_module_open(modname, G_MODULE_BIND_LAZY);
    if (handle) {
      spd_open2_t spdo2;
      if (g_module_symbol(handle, "spd_open2", (gpointer *)&spdo2))
        spd = (*spdo2)("mwp", NULL, NULL, SPD_MODE_SINGLE, NULL, 1, NULL);
      if (spd) {
        spd_set_voice_type_t sssv;
        spd_set_language_t ssl;
        spd_set_volume_t ssv;
        spd_set_notification_on_t ssno;

        if (g_module_symbol(handle, "spd_set_language", (gpointer *)&ssl))
          (*ssl)(spd, "en");
        if (g_module_symbol(handle, "spd_set_voice_type", (gpointer *)&sssv)) {
          SPDVoiceType vt;
          if (strcmp(voice, "male2"))
            vt = SPD_MALE2;
          else if (strcmp(voice, "male3"))
            vt = SPD_MALE3;
          else if (strcmp(voice, "female1"))
            vt = SPD_FEMALE1;
          else if (strcmp(voice, "female2"))
            vt = SPD_FEMALE2;
          else if (strcmp(voice, "female3"))
            vt = SPD_FEMALE3;
          else if (strcmp(voice, "child_male"))
            vt = SPD_CHILD_MALE;
          else if (strcmp(voice, "child_female"))
            vt = SPD_CHILD_FEMALE;
          else
            vt = SPD_MALE1;
          (*sssv)(spd, vt);
        }

        if (g_module_symbol(handle, "spd_set_volume", (gpointer *)&ssv))
          (*ssv)(spd, -50);
        if (g_module_symbol(handle, "spd_set_notification_on", (gpointer *)&ssno)) {
          spd->callback_end = spd->callback_cancel = end_of_speech;
          (*ssno)(spd, SPD_END);
          (*ssno)(spd, SPD_CANCEL);
        }
        if (g_module_symbol(handle, "spd_say", (gpointer *)&ssay))
          ret = API_SPEECHD;
      }
    }
    g_free(modname);
  }
  return ret;
}
static void sd_say(char *text) {
  if (spd) {
    g_mutex_lock(&s_mutex);
    (*ssay)(spd, SPD_TEXT, text);
    g_cond_wait(&s_cond, &s_mutex);
    g_mutex_unlock(&s_mutex);
  }
}

static void sd_close(void) {
  if (spd) {
    spd_close_t spdc;
    if (g_module_symbol(handle, "spd_cancel_all", (gpointer *)&spdc)) {
      (*spdc)(spd);
    }
    if (g_module_symbol(handle, "spd_close", (gpointer *)&spdc)) {
      (*spdc)(spd);
      spd = NULL;
    }
  }
}
#endif

#ifdef USE_FLITE

#include <flite/flite.h>
#include <flite/flite_version.h>

typedef cst_voice *(*register_cmu_us_slt_t)(void);
typedef void (*usenglish_init_t)(cst_voice *);
typedef cst_lexicon *(*cmulex_init_t)(void);
typedef void (*flite_init_t)(void);
typedef int (*flite_add_lang_t)(char *, void *, void *);
typedef cst_voice *(*flite_voice_load_t)(char *);
typedef float (*flite_text_to_speech_t)(char *, cst_voice *, char *);
typedef void (*feat_set_float_t)(cst_features *, char *, float);
typedef const char *(*feat_string_t)(cst_features *, const char *);
static cst_voice *voice;
static flite_text_to_speech_t fl_tts;
static usenglish_init_t fl_eng;
static cmulex_init_t fl_cmu;

static int fl_init(char *vname) {
  if (FLITE_PROJECT_VERSION[0] < '2') {
    mwp_log_message("flite requires version 2 or later, this is %s: disabling\n", FLITE_PROJECT_VERSION);
    goto out;
  }

  gchar *modname;
  modname = m_module_build_path(NULL, "flite");
  if (modname) {
    handle = g_module_open(modname, 0);
    if (handle) {
      flite_init_t fl_i;
      if (g_module_symbol(handle, "flite_init", (gpointer *)&fl_i)) {
        (*fl_i)();
        flite_add_lang_t fl_al;
        flite_voice_load_t fl_load;
        feat_set_float_t fl_fsf;
        feat_string_t fl_fstr;

        g_module_symbol(handle, "flite_add_lang", (gpointer *)&fl_al);
        g_module_symbol(handle, "flite_voice_load", (gpointer *)&fl_load);
        g_module_symbol(handle, "feat_set_float", (gpointer *)&fl_fsf);
        g_module_symbol(handle, "feat_string", (gpointer *)&fl_fstr);
        g_module_symbol(handle, "flite_text_to_speech", (gpointer *)&fl_tts);
        GModule *handle2;
        modname = m_module_build_path(NULL, "flite_usenglish");
        handle2 = g_module_open(modname, 0);
        if (handle2 == NULL)
          goto out;
        g_module_symbol(handle2, "usenglish_init", (gpointer *)&fl_eng);

        GModule *handle3;
        modname = m_module_build_path(NULL, "flite_cmulex");
        handle3 = g_module_open(modname, 0);
        if (handle3 == NULL)
          goto out;

        g_module_symbol(handle3, "cmulex_init", (gpointer *)&fl_cmu);
        if (fl_al == NULL || fl_load == NULL || fl_tts == NULL || fl_eng == NULL || fl_cmu == NULL || fl_fstr == NULL ||
            fl_fsf == NULL)
          goto out;

        int i0 = (*fl_al)("eng", fl_eng, fl_cmu);
        int i1 = (*fl_al)("usenglish", fl_eng, fl_cmu);
        if (i0 != 1 || i1 != 1)
          goto out;

        GModule *handle1;
        modname = m_module_build_path(NULL, "flite_cmu_us_slt");
        handle1 = g_module_open(modname, 0);
        if (handle1 == NULL)
          goto out;
        register_cmu_us_slt_t fl_slt;
        g_module_symbol(handle1, "register_cmu_us_slt", (gpointer *)&fl_slt);

        char *parts[2] = {NULL};
        float f = 0.0;

        if (vname != NULL && fl_load != NULL && vname != NULL) {
          char *s, *dup = NULL;
          dup = s = strdup(vname);
          int n = 0;
          char *tok;
          while ((tok = strsep(&s, ","))) {
            if (n < 2)
              parts[n] = tok;
            n++;
          }
          if (parts[0] != NULL && parts[0] != 0)
            voice = (*fl_load)(parts[0]);

          if (parts[1] != NULL && parts[1] != 0)
            f = atof(parts[1]);
          free(dup);
        }
        if (voice == NULL && fl_slt != NULL)
          voice = (*fl_slt)();
        if (f != 0.0)
          (*fl_fsf)(voice->features, "duration_stretch", f);
        const char *name = (*fl_fstr)(voice->features, "name");
        mwp_log_message("flite voice = %s\n", name);
      }
    }
  }
out:
  return (voice == NULL) ? API_NONE : API_FLITE;
}

static void fl_say(char *text) { (*fl_tts)(text, voice, "play"); }

#endif
#endif

unsigned char get_speech_api_mask() {
  guchar api_mask = 0;
#ifdef USE_ESPEAK
  api_mask |= 1;
#endif
#ifdef USE_SPEECHD
  api_mask |= 2;
#endif
#ifdef USE_FLITE
  api_mask |= 4;
#endif
  return api_mask;
}

static int ss_init(char *v) { return 0; }

static void ss_say(char *t) { mwp_log_message("null speech say %s\n", t); }

static void ss_close(void) {}

static int (*_speech_init)(char *) = ss_init;
static void (*_speech_say)(char *) = ss_say;
static void (*_speech_close)(void) = ss_close;

void speech_set_api(unsigned char api) {
#ifdef USE_ESPEAK
  if (api == 1) {
    _speech_init = ep_init;
    _speech_say = ep_say;
    return;
  }
#endif
#ifdef USE_SPEECHD
  if (api == 2) {
    _speech_init = sd_init;
    _speech_say = sd_say;
    _speech_close = sd_close;
    return;
  }
#endif
#ifdef USE_FLITE
  if (api == 3) {
    _speech_init = fl_init;
    _speech_say = fl_say;
    return;
  }
#endif
}

int speech_init(char *voice) {
  int res = (*_speech_init)(voice);
  if (res == API_NONE)
    _speech_say = ss_say;
  return res;
}

void speech_say(char *text) { (*_speech_say)(text); }

void speech_close(void) { (*_speech_close)(); }
