#include <stdbool.h>

extern int connect_bt_device (const char *dev, int* lasterr);

extern void speech_set_api(char a);
extern unsigned char get_speech_api_mask();
extern int speech_init(const char *voice);
extern void speech_say(const char *text);
extern void speech_close(void);

#ifndef __WIN64
extern __attribute__((weak)) const char *__progname;
#endif
extern const char * get_build();
extern const char * get_id();
extern const char * get_build_host();
extern const char * get_build_compiler();

extern void start_cpu_stats();
extern int end_cpu_stats(double *cpu0, double* cpu1);

#define MWP_MISC_MWP_MAX_WP 60
