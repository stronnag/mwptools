#include <stdint.h>

#define READ_SB_DISTNDEF 0xffffffff

typedef struct {
  uint32_t addr;
  int32_t alt;
  uint32_t hdg;
  uint32_t speed;
  uint32_t seen_pos;
  uint32_t srange;
  double lat;
  double lon;
  uint8_t catx;
  char name[9];
  uint64_t seen_tm;
} readsb_pb_t;

extern int decode_ac_pb(uint8_t *input_array, size_t input_length,
			readsb_pb_t **output_array, int* output_length);
