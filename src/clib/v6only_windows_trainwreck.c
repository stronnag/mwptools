#ifdef WIN64
#include <winsock2.h>
#include <windows.h>
#include <ws2ipdef.h>

int set_v6_dual_stack(int fd) {
  int v6only=0;
  int err = setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, (char*)&v6only, sizeof(v6only));
  return err;
}
#else
int set_v6_dual_stack(int fd) {
  return 0;
}
#endif
