#include <stdint.h>

#ifdef HAVE_GATTLIB
#include <gattlib.h>
#else
typedef void gatt_connection_t;
#endif

typedef enum {
  GATT_OK=0,
  GATT_CONNFAIL=1,
  GATT_NOTFAIL=2,
  GATT_CCFAIL=3,
  GATT_NODEV=4,
  GATT_NOCHAR=5,
  GATT_UNAVAIL=255,
} gatt_err_e;

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
