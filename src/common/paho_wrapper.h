#include <MQTTClient.h>

extern MQTTClient paho_wrapper_setup(const char *server, const char *cafile);
extern int paho_wrapper_subscribe(MQTTClient client, const char *topic);
extern int paho_wrapper_unsubscribe(MQTTClient client, const char *topic);
extern void paho_wrapper_disconnect(MQTTClient client);
extern void paho_wrapper_cleanup(MQTTClient client);
extern int paho_wrapper_poll_message(MQTTClient client, char **str);
extern int paho_wrapper_last_error(void);
