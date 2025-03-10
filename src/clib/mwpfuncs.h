#include <stdbool.h>
#include <stdint.h>

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

extern char** check_ports();
extern int check_insert_name(char *s);
extern int check_delete_name(char *s);

extern int set_v6_dual_stack(int fd);
extern int set_bin_mode(int m);

#define MWP_MISC_MWP_MAX_WP 60

typedef struct  __attribute__ ((__packed__))   {
  double et;
  uint16_t len;
  uint8_t dirn;
} _smwprawhdr_t;


typedef union  {
  _smwprawhdr_t s;
  uint8_t bytes[sizeof(_smwprawhdr_t)];
} _mwprawhdr_t;
