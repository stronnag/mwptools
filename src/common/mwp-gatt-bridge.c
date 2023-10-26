

#define _GNU_SOURCE

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdbool.h>

#define GATT_OK 0
#define GATT_CONNFAIL 1
#define GATT_NOTFAIL 2
#define GATT_NOCHAR 5
#define GATT_CCFAIL 3
#define GATT_NODEV 4
#define GATT_UNAVAIL 255

#ifdef HAVE_GATTLIB
#include <gattlib.h>
#include "mwp-gatt-bridge.h"


typedef struct {
  char *name;
  char *sv_uuid;
  char *tx_uuid;
  char *rx_uuid;
} RWUUID_t;

static const RWUUID_t uuids[] = {{
      "CC2541 based",
      "0000ffe0-0000-1000-8000-00805f9b34fb",
      "0000ffe1-0000-1000-8000-00805f9b34fb",
      "0000ffe1-0000-1000-8000-00805f9b34fb",
    },{
      "Nordic Semiconductor NRF",
      "6e400001-b5a3-f393-e0a9-e50e24dcca9e",
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e",
      "6e400002-b5a3-f393-e0a9-e50e24dcca9e",
    },{
      "SpeedyBee Type 2",
      "0000abf0-0000-1000-8000-00805f9b34fb",
      "0000abf1-0000-1000-8000-00805f9b34fb",
      "0000abf2-0000-1000-8000-00805f9b34fb",
    },{
      "SpeedyBee Type 1",
      "00001000-0000-1000-8000-00805f9b34fb",
      "00001001-0000-1000-8000-00805f9b34fb",
      "00001002-0000-1000-8000-00805f9b34fb",
    }
};

#define N_UUIDS (sizeof uuids/sizeof(RWUUID_t))

static void mwp_gatt_notify_cb(const uuid_t* uuid, const uint8_t* data, size_t length, void* udata) {
  gattclient_t *gc = udata;
  if (gc->mfd != -1) {
    ssize_t n =  write(gc->mfd, data, length);
    if (n == -1) {
      close(gc->mfd);
      gc->mfd = -1;
    }
  }
}

void mwp_gatt_close(gattclient_t *gc) {
  if (gc != NULL) {
    if (gc->mfd != -1) {
      close(gc->mfd);
    }
    free(gc->uxdev);
    gattlib_disconnect(gc->connection);
    free(gc);
  }
}

gattclient_t * new_mwp_gatt(char *uuid, int*status) {
  uuid_t characteristic_tx_uuid;
  uuid_t characteristic_rx_uuid;

  gattclient_t * gc = NULL;
  gatt_connection_t*  m_connection = gattlib_connect(NULL, uuid, GATTLIB_CONNECTION_OPTIONS_LEGACY_BDADDR_LE_RANDOM | GATTLIB_CONNECTION_OPTIONS_LEGACY_BT_SEC_LOW);
  if (m_connection == NULL) {
    if (status != NULL) {
      *status = GATT_CONNFAIL;
    }
    return NULL;
  }

  int k = -1;
  gattlib_characteristic_t* characteristics = NULL;
  int characteristic_count;
  int ret = gattlib_discover_char(m_connection, &characteristics, &characteristic_count);
  if (ret) {
    if (status) {
      *status =  GATT_NOCHAR;
    }
    free(characteristics);
    gattlib_disconnect(m_connection);
    return NULL;
  }

  uint16_t tx_handle = 0, rx_handle = 0;
  for(int j = 0; j < N_UUIDS; j++) {
    ret = gattlib_string_to_uuid(uuids[j].tx_uuid, strlen(uuids[j].tx_uuid) + 1, &characteristic_tx_uuid);
    if (ret) {
      if (status) {
	*status = GATT_CCFAIL;
      }
      free(characteristics);
      gattlib_disconnect(m_connection);
      return NULL;
    }
    ret = gattlib_string_to_uuid(uuids[j].rx_uuid, strlen(uuids[j].rx_uuid) + 1, &characteristic_rx_uuid);
    if (ret) {
      if (status) {
	*status = GATT_CCFAIL;
      }
      free(characteristics);
      gattlib_disconnect(m_connection);
      return NULL;
    }

    for (int i = 0; i < characteristic_count; i++) {
      if (gattlib_uuid_cmp(&characteristics[i].uuid, &characteristic_tx_uuid) == 0) {
	tx_handle = characteristics[i].value_handle;
      } else if (gattlib_uuid_cmp(&characteristics[i].uuid, &characteristic_rx_uuid) == 0) {
	rx_handle = characteristics[i].value_handle;
      }
    }
    if (tx_handle != 0 && rx_handle !=0 ) {
      k = j;
      break;
    }
  }
  free(characteristics);
  if (k != -1) {
    gc = calloc(1,sizeof(gattclient_t));
    gc->mfd = -1;
    gattlib_register_notification(m_connection, mwp_gatt_notify_cb, gc);
    ret = gattlib_notification_start(m_connection, &characteristic_rx_uuid);
    if (ret) {
      if (status) {
	*status = GATT_NOTFAIL;
      }
      free(gc);
      return NULL;
    }
  } else {
      if (status) {
	*status = GATT_NODEV;
      }
      return NULL;
  }
  gc->connection = m_connection;
  gc->tx_handle = tx_handle;
  gc->rx_handle = rx_handle;
  gc->name = uuids[k].name;
  gc->mfd = posix_openpt(O_RDWR);
  if (gc->mfd != 1) {
    grantpt(gc->mfd);
    unlockpt(gc->mfd);
    gc->uxdev = malloc(80);
    ptsname_r(gc->mfd, gc->uxdev, 80);
  }
  if (status) {
    *status = GATT_OK;
  }
  return gc;
}

static int mwp_gatt_writer(gattclient_t *gc, void* buf, size_t buflen) {
  uint8_t *ptr = (uint8_t*)buf;
  int ret, len;
  for(len = (int)buflen; len > 0; ) {
    int n;
    if (len > 20) {
      n = 20;
    } else {
      n = len;
    }
    ret = gattlib_write_without_response_char_by_handle(gc->connection, gc->tx_handle, ptr, n);
    if (ret) {
      return ret;
    }
    ptr += n;
    len -= n;
  }
  return 0;
}

void mwp_gatt_bridge(gattclient_t *gc) {
  int n;
  int n1;
  char input[32];
  while(true) {
    n = read(gc->mfd, input, 20);
    if (n > 0) {
      n1 = mwp_gatt_writer(gc, input, n);
      if (n1 != 0)
	break;
    } else {
      break;
    }
  }
  //  mwp_gatt_close(gc);
}
char * mwp_gatt_devnode(gattclient_t *gc) {
  return gc->uxdev;
}
#else
typedef void gattclient_t;
void mwp_gatt_bridge(gattclient_t *gc, int *done) {
}
gattclient_t * new_mwp_gatt(char *uuid, int*status) {
  if (status) {
    *status = GATT_UNAVAIL;
  }
  return NULL;
}
char * mwp_gatt_devnode(gattclient_t *gc) {
  return NULL;
}
#endif

#ifdef TEST
int done = 0;
void cc_handler(int dummy) {
  done = 1;
}

int main(int argc, char *argv[]) {
  char* devid;
  gattclient_t *gc;
  int ret = 0;

  devid = (argc == 2) ? argv[1] : "60:55:F9:A5:7B:16";
  gc = new_mwp_gatt(devid, &ret);
  if (gc != NULL) {
    printf("PTS = %s\n", mwp_gatt_devnode(gc));
    signal(SIGINT, cc_handler);
    mwp_gatt_bridge(gc, &done);
  } else {
    fprintf(stderr, "failed to open %s %d\n", devid, ret);
  }
  return 0;
}
#endif
