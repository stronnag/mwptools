typedef struct {
  char *dspname;
  char *devname;
} cam_dev_t;

extern cam_dev_t * get_cameras(int*res, int *nlen);
extern void cam_dev_destroy(cam_dev_t *c);
extern void cam_dev_copy(cam_dev_t *d, cam_dev_t *s);
