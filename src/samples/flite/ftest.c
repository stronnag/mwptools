#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <glib.h>
#include <gmodule.h>

#include <flite/flite.h>
#include <flite //flite_version.h>

typedef cst_voice *(*register_internal_t)(void);
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
static GModule *handle;

static int fl_init(char *vname) {
  /**
   * for this test we allow old versions

if(FLITE_PROJECT_VERSION[0] < '2')
{
  fprintf(stderr, "flite requires version 2 or later, this is %s: disabling\n", FLITE_PROJECT_VERSION);
  goto out;
}
  **/
  gchar *modname;
  modname = g_module_build_path(NULL, "flite");
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
        modname = g_module_build_path(NULL, "flite_usenglish");
        handle2 = g_module_open(modname, 0);
        if (handle2 == NULL)
          goto out;
        g_module_symbol(handle2, "usenglish_init", (gpointer *)&fl_eng);

        GModule *handle3;
        modname = g_module_build_path(NULL, "flite_cmulex");
        handle3 = g_module_open(modname, 0);

        if (handle3 == NULL)
          goto out;
        g_module_symbol(handle3, "cmulex_init", (gpointer *)&fl_cmu);

        /* Tests relaxed here so 1.3 works */
        if (/*fl_al == NULL || fl_load == NULL || */ fl_tts == NULL || fl_eng == NULL ||
            /*fl_cmu == NULL || */ fl_fstr == NULL || fl_fsf == NULL)
          goto out;

        if (fl_al != NULL) {
          int i0 = (*fl_al)("eng", fl_eng, fl_cmu);
          int i1 = (*fl_al)("usenglish", fl_eng, fl_cmu);
          if (i0 != 1 || i1 != 1)
            goto out;
        }

        GModule *handle1;
        register_internal_t fl_slt;
        modname = g_module_build_path(NULL, "flite_cmu_us_slt");
        handle1 = g_module_open(modname, 0);
        if (handle1 != NULL)
          g_module_symbol(handle1, "register_cmu_us_slt", (gpointer *)&fl_slt);
        else {
          modname = g_module_build_path(NULL, "flite_cmu_us_kal");
          handle1 = g_module_open(modname, 0);
          if (handle1 != NULL)
            g_module_symbol(handle1, "register_cmu_us_kal", (gpointer *)&fl_slt);
        }
        if (fl_slt == NULL)
          goto out;

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
        fprintf(stderr, "flite voice = %s\n", name);
      }
    }
  }
out:
  return (voice == NULL) ? -1 : 0;
}

static float fl_say(char *text) { return (*fl_tts)(text, voice, "play"); }

int main(int argc, char **argv) {
  char buf[1024];

  if (fl_init(argv[1]) == 0) {
    setvbuf(stdin, NULL, _IOLBF, 1024);
    setvbuf(stdout, NULL, _IONBF, 1024);
    while (fgets(buf, 1024, stdin) != NULL) {
      int n = strlen(buf);
      buf[n - 1] = 0;
      printf("%s ", buf);
      float r = fl_say(buf);
      printf(" (%.2fs)\n", r);
    }
  } else
    puts("flite init fails\n");

  return 0;
}
