#include <stddef.h>
#include <stdlib.h>
#include <stdint.h>

extern int open_serial(const char * name, int baudrate);
extern ssize_t read_serial(int fd, unsigned char *buf, size_t buflen);
extern ssize_t write_serial(int fd, unsigned char *buf, size_t buflen);
extern void close_serial(int fd);
extern void flush_serial(int fd);
extern char *get_error_text(int dummy, char *pBuf, size_t bufSize);
extern int set_fd_speed(int fd, int rate);
extern int cf_pipe(int *fds);
extern int get_error_number();
