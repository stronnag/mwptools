
#include <stdbool.h>

extern int open_serial(const char * dev, guint baudrate);
extern void close_serial(int fd);
extern void flush_serial(int fd);
extern int set_fd_speed(int fd, int baudrate, int*);
extern char * default_name(void);
extern char * get_error_text(int err, char* buf, size_t len);

extern int connect_bt_device (const char *dev, int* lasterr);

extern int cf_pipe(int *fds);
extern int cf_pipe_close(int fd);

extern void speech_set_api(char a);
extern unsigned char get_speech_api_mask();
extern int speech_init(const char *voice);
extern void speech_say(const char *text);
extern void speech_close(void);

extern bool is_cygwin();
extern char* get_native_path(char *);

extern char *__progname;
extern const char * get_build();
extern const char * get_id();
extern const char * get_build_host();
extern const char * get_build_compiler();

extern void get_glinfo(char **vendp, char **rendp);

#define MWP_MISC_MWP_MAX_WP 60
