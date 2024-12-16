#include <windows.h>
#include <stdint.h>

static unsigned int mPrevScreenSaver;

void uninhibit(unsigned int cookie) {
  SystemParametersInfo(SPI_SETSCREENSAVETIMEOUT, mPrevScreenSaver, NULL, 0);
  SetThreadExecutionState(cookie);
}

unsigned int inhibit(void) {
  unsigned int cookie = SetThreadExecutionState(ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED | ES_CONTINUOUS);
  SystemParametersInfo(SPI_GETSCREENSAVETIMEOUT, 0, &mPrevScreenSaver, 0);
  SystemParametersInfo(SPI_SETSCREENSAVETIMEOUT, FALSE, NULL, 0);
  return cookie;
}

#if TEST
#include <stdio.h>
#include <unistd.h>

int main(int argc, char**argv) {
  int isleep = 120;

  if(argc > 1) {
    isleep = atoi(argv[1]);
  }

  unsigned int cookie = inhibit();
  printf("cookie = %u\n", cookie);
  sleep(isleep);
  printf("uninhibit() %x\n", mPrevScreenSaver);
}
#endif
