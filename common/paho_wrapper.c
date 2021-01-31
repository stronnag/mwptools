/*******************************************************************************
 * Copyright (c) 2012, 2020 IBM Corp.
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v2.0
 * and Eclipse Distribution License v1.0 which accompany this distribution.
 *
 * The Eclipse Public License is available at
 *   https://www.eclipse.org/legal/epl-2.0/
 * and the Eclipse Distribution License is available at
 *   http://www.eclipse.org/org/documents/edl-v10.php.
 *
 * Contributors:
 *    Ian Craggs - initial contribution
 *******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "paho_wrapper.h"

#define QOS 0

static int rc_open;

int paho_wrapper_last_error(void) {
     return rc_open;
}

MQTTClient paho_wrapper_setup(const char *host, const char *cafile)
{
     MQTTClient client = NULL;
     MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;
     MQTTClient_SSLOptions ssl_opts = MQTTClient_SSLOptions_initializer;

     MQTTClient_init_options inits = MQTTClient_init_options_initializer;
     inits.do_openssl_init = 1;
     MQTTClient_global_init(&inits);

     if((strncmp(host, "ssl://", 6) == 0 || strncmp(host, "wss://", 6) == 0))
     {
          ssl_opts.verify = 0;
          ssl_opts.trustStore = cafile;
          /*
          ssl_opts.CApath = cafile;
          ssl_opts.keyStore = NULL;
          ssl_opts.privateKey = NULL;
          ssl_opts.privateKeyPassword = NULL;
          ssl_opts.enabledCipherSuites = "aNULL";
          */
          conn_opts.ssl = &ssl_opts;
     }

     long rno = random();
     char clientid[16];
     sprintf(clientid, "_%08x_", rno);

     if ((rc_open = MQTTClient_create(&client, host, clientid,
                                 MQTTCLIENT_PERSISTENCE_NONE, NULL)) == MQTTCLIENT_SUCCESS)
     {
          if ((rc_open = MQTTClient_connect(client, &conn_opts)) == MQTTCLIENT_SUCCESS)
          {
               return client;
          }
     }
     MQTTClient_destroy(&client);
     return NULL;
}

int paho_wrapper_subscribe(MQTTClient client, const char *topic)
{
     return MQTTClient_subscribe(client, topic, QOS);
}

int paho_wrapper_unsubscribe(MQTTClient client, const char *topic)
{
     return MQTTClient_unsubscribe(client, topic);
}

void paho_wrapper_disconnect(MQTTClient client)
{
     MQTTClient_disconnect(client, 10000);
}

void paho_wrapper_cleanup(MQTTClient client)
{
     MQTTClient_destroy(&client);
}

int paho_wrapper_poll_message(MQTTClient client, char **str)
{
     *str = NULL;
     char * topic;
     int tlen;
     MQTTClient_message *message;

     int rc = MQTTClient_receive(client, &topic, &tlen, &message, 1000);
     if ( rc ==  MQTTCLIENT_SUCCESS && message != NULL)
     {
          *str = calloc(1, message->payloadlen+1);
          strncpy(*str, (char*)message->payload, message->payloadlen);
          MQTTClient_freeMessage(&message);
          MQTTClient_free(topic);
     }
     return rc;
}
