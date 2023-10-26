#include <stdint.h>
#include <gattlib.h>

typedef struct {
  gatt_connection_t* connection;
  char *name;
  char *uxdev;
  int mfd;
  uint16_t tx_handle;
  uint16_t rx_handle;
} gattclient_t;

extern void mwp_gatt_close(gattclient_t *);
extern gattclient_t * new_mwp_gatt(char *, int*);
extern void mwp_gatt_bridge(gattclient_t *);
extern char * mwp_gatt_devnode(gattclient_t *);
