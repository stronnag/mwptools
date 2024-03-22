[CCode (cheader_filename = "mosquitto.h")]
namespace Mosquitto {

    [CCode (cname = "on_connect", has_target = false)]
    public delegate void on_connect (Client client, void *obj, int rc);

    [CCode (cname = "on_connect", has_target = false)]
    public delegate void on_connect_with_flags (Client client, void *obj, int rc, int flags);
    
    [CCode (cname = "on_disconnect", has_target = false)]
    public delegate void on_disconnect (Client client, void *obj, int rc);

    [CCode (cname = "on_publish", has_target = false)]
    public delegate void on_publish (Client client, void *obj, int mid);

    [CCode (cname = "on_message", has_target = false)]
    public delegate void on_message (Client client, void *obj, Mosquitto.Message message);

    [CCode (cname = "on_subscribe", has_target = false)]
    public delegate void on_subscribe (Client client, void *obj, int mid, int qos_count, [CCode (array_length = false)] int[] granted_qos);

    [CCode (cname = "pw_callback", has_target = false)]
    public delegate int pw_callback (Client client, string? buf, int size, int rwflag);

    [CCode (cname = "on_unsubscribe", has_target = false)]
    public delegate void on_unsubscribe (Client client, void *obj, int mid);

    [CCode (cname = "on_log", has_target = false)]
    public delegate void on_log (Client client, void *obj, int level, string str);

    [CCode (cname="mosq_err_t", cprefix = "MOSQ_ERR_", has_type_id = false)]
    public enum Error {
        CONN_PENDING,
        SUCCESS,
        NOMEM,
        PROTOCOL,
        INVAL,
        NO_CONN,
        CONN_REFUSED,
        NOT_FOUND,
        CONN_LOST,
        TLS,
        PAYLOAD_SIZE,
        NOT_SUPPORTED,
        AUTH,
        ACL_DENIED,
        UNKNOWN,
        ERRNO,
        EAI,
        PROXY,
        PLUGIN_DEFER,
        MALFORMED_UTF8,
        KEEPALIVE,
        LOOKUP,
    }

    [CCode (cname="mosq_opt_t", cprefix = "MOSQ_OPT_", has_type_id = false)]
    public enum Options {
        PROTOCOL_VERSION,
        SSL_CTX,
        SSL_CTX_WITH_DEFAULTS,
    }

    public const int LIBMOSQUITTO_MAJOR;
    public const int LIBMOSQUITTO_MINOR;
    public const int LIBMOSQUITTO_REVISION;
    public const int LIBMOSQUITTO_VERSION_NUMBER;

    [CCode (cname = "int", cprefix = "MOSQ_LOG_", has_type_id = false)]
    [Flags]
    public enum Log {
        NONE,
        INFO,
        NOTICE,
        WARNING,
        ERR,
        DEBUG,
        SUBSCRIBE,
        UNSUBSCRIBE,
        WEBSOCKETS,
        ALL,
    }

    public const int MOSQ_MQTT_ID_MAX_LENGTH;
    public const int MQTT_PROTOCOL_V31;
    public const int MQTT_PROTOCOL_V311;

    [CCode (cname = "mosquitto_lib_version")]
    public int version (out int major, out int minor, out int revision);

    [CCode (cname = "mosquitto_lib_init")]
    public void init ();

    [CCode (cname = "mosquitto_lib_cleanup")]
    public void cleanup ();

    [CCode (cname = "mosquitto_strerror")]
    public unowned string strerror (int errno);

    [CCode (cname = "mosquitto_connack_string")]
    public unowned string connack_string (int connack_code);

    // Vala tries to free the string and tokens free may be redundant
    [CCode (cname = "mosquitto_sub_topic_tokenise")]
    public int sub_topic_tokenise (string? subtopic, out string[] topics); 

    [CCode (cname = "mosquitto_sub_topic_tokens_free")]
    public int sub_topic_tokens_free (string[] topics);

    [CCode (cname = "mosquitto_topic_matches_sub")]
    public int topic_matches_sub (string? sub, string? topic, out bool result);

    [CCode (cname = "mosquitto_topic_matches_sub2")]
    public int topic_matches_sub2 (string? sub, size_t sublen, string? topic, size_t topiclen, out bool result);

    [CCode (cname = "mosquitto_pub_topic_check")]
    public int pub_topic_check (string? topic);

    [CCode (cname = "mosquitto_pub_topic_check2")]
    public int pub_topic_check2 (string? topic, size_t topic_len);

    [CCode (cname = "mosquitto_sub_topic_check")]
    public int sub_topic_check (string? topic);

    [CCode (cname = "mosquitto_sub_topic_check2")]
    public int sub_topic_check2 (string? topic, size_t topic_len);

    [CCode (cname = "mosquitto_subscribe_simple")]
    public int subscribe_simple (string[] messages, int msg_count, bool want_retained, string? topic, int qos, string? host, int port, string? client_id, int keepalive, bool clean_session, string? username, string? password, Will will, Tls tls);

    [CCode (cname = "mosquitto_subscribe_callback")]
    public int subscribe_callback (on_message callback, void *userdata, string? topic, int qos, string? host, int port, string? client_id, int keepalive, bool clean_session, string? username, string? password, Will will, Tls tls);

    [CCode (cname = "mosquitto_validate_utf8")]
    public int validate_utf8 (string? str, int len);


    [CCode (cname = "libmosquitto_will", has_type_id = false)]
    public struct Will {
        string topic;
        uint8[] payload;
        int payloadlen;
        int qos;
        bool retain;
    }

    [CCode (cname = "libmosquitto_auth", has_type_id = false)]
    public struct Auth {
        string username;
        string password;
    }

    [CCode (cname = "libmosquitto_tls")]
    public struct Tls {
        string cafile;
        string capath;
        string certfile;
        string keyfile;
        string chipers;
        string tls_version;
        pw_callback callback;
        int cert_reqs;
    }

    
    /* Should not be instantiated (stack). Methods are for private allocated instances */
    [CCode (cname = "struct mosquitto_message", destroy_function = "mosquitto_message_free", has_type_id = false)]
    public struct Message {
        int mid;
        string topic;
        string payload; /* Should be uint8[] but valac generates a non existent payload length */
        int payloadlen;
        int qos;
        bool retain;
        
        [CCode (cname = "mosquitto_message_copy", has_type_id = false)]
        public static int copy (Message dst, Message src);

        [CCode (cname = "mosquitto_message_free_contents", has_type_id = false)]
        public void free_contents ();
    }

    [CCode (cname = "struct mosquitto", free_function = "mosquitto_destroy", has_type_id = false)]
    [Compact]
    public class Client {
        [CCode (cname = "mosquitto_new")]
        public Client (string? id = null, bool clean_session = true, void *obj = null);

        [CCode (cname = "mosquitto_reinitialise")]
        public int reinitialise (string? id = null, bool clean_session = true, void *obj = null);

        [CCode (cname = "mosquitto_will_set")]
        public int will_set (string topic, [CCode (array_length_pos = 1.2)] uint8[] payload, int qos, bool retain); 

        [CCode (cname = "mosquitto_will_clear")]
        public int will_clear ();

        [CCode (cname = "mosquitto_username_pw_set")]
        public int username_pw_set (string username, string password);

        [CCode (cname = "mosquitto_connect")]
        public int connect (string host, int port, int keepalive);

        [CCode (cname = "mosquitto_connect_bind")]
        public int connect_bind (string host, int port, int keepalive, string bind_address);

        [CCode (cname = "mosquitto_connect_async")]
        public int connect_async (string host, int port, int keepalive, string bind_address);

        [CCode (cname = "mosquitto_connect_bind_async")]
        public int connect_bind_async (string host, int port, int keepalive, string bind_address);

        [CCode (cname = "mosquitto_connect_srv")]
        public int connect_srv (string host, int port, int keepalive, string bind_address);

        [CCode (cname = "mosquitto_reconnect")]
        public int reconnect ();

        [CCode (cname = "mosquitto_reconnect_async")]
        public int reconnect_async ();

        [CCode (cname = "mosquitto_disconnect")]
        public int disconnect ();

        [CCode (cname = "mosquitto_publish")]
        public int publish (int? mid, string topic, [CCode (array_length_pos = 2.1)] uint8[] payload, int qos, bool retain);

        [CCode (cname = "mosquitto_subscribe")]
        public int subscribe (int? mid, string? sub, int qos);

        [CCode (cname = "mosquitto_unsubscribe")]
        public int unsubscribe (int? mid, string? sub);

        [CCode (cname = "mosquitto_loop")]
        public int loop (int timeout, int maxpackets);

        [CCode (cname = "mosquitto_loop_forever")]
        public int loop_forever (int timeout, int maxpackets);

        [CCode (cname = "mosquitto_loop_start")]
        public int loop_start ();
    
        [CCode (cname = "mosquitto_loop_stop")]
        public int loop_stop (bool force);

        [CCode (cname = "mosquitto_socket")]
        public int loop_socket ();

        [CCode (cname = "mosquitto_loop_read")]
        public int loop_read (int max_packets);

        [CCode (cname = "mosquitto_loop_write")]
        public int loop_write (int max_packets);
        
        [CCode (cname = "mosquitto_loop_misc")]
        public int loop_misc ();

        [CCode (cname = "mosquitto_want_write")]
        public int want_write ();

        [CCode (cname = "mosquitto_threaded_set")]
        public int threaded_set (bool threaded);

        [CCode (cname = "mosquitto_opts_set")]
        public int opts_set (Options option);

        [CCode (cname = "mosquitto_tls_set")]
        public int tls_set (string? cafile, string? capath, string? certfile, string? keyfile, pw_callback callback);

        [CCode (cname = "mosquitto_tls_insecure_set")]
        public int tls_insecure_set (bool value);

        [CCode (cname = "mosquitto_tls_opts_set")]
        public int tls_opts_set (int cert_reqs, string? tls_version, string? chipers);

        [CCode (cname = "mosquitto_tls_psk_set")]
        public int tls_psk_set (string? psk, string? identity, string? chipers);

        [CCode (cname = "mosquitto_connect_callback_set", has_target = false)]
        public void connect_callback_set (on_connect callback);

        [CCode (cname = "mosquitto_connect_with_flags_callback_set", has_target = false)]
        public void connect_with_flags_callback_set (on_connect_with_flags callback);

        [CCode (cname = "mosquitto_disconnect_callback_set", has_target = false)]
        public void disconnect_callback_set (on_disconnect callback);

        [CCode (cname = "mosquitto_publish_callback_set", has_target = false)]
        public void publish_callback_set (on_publish callback);

        [CCode (cname = "mosquitto_message_callback_set", has_target = false)]
        public void message_callback_set (on_message callback);

        [CCode (cname = "mosquitto_subscribe_callback_set", has_target = false)]
        public void subscribe_callback_set (on_subscribe callback);

        [CCode (cname = "mosquitto_unsubscribe_callback_set", has_target = false)]
        public void unsubscribe_callback_set (on_unsubscribe callback);

        [CCode (cname = "mosquitto_log_callback_set", has_target = false)]
        public void log_callback_set (on_log callback);

        [CCode (cname = "mosquitto_reconnect_delay_set")]
        public int reconnect_delay_set (uint reconnect_delay, uint reconnect_delay_max, bool reconnect_exponential_backoff);

        [CCode (cname = "mosquitto_max_inflight_messages_set")]
        public int max_inflight_messages_set (int max_inflight_messages);

        [CCode (cname = "mosquitto_message_retry_set")]
        public int message_retry_set (uint message_retry); 

        [CCode (cname = "mosquitto_user_data_set")]
        public int user_data_set (void *user_data); 

        [CCode (cname = "mosquitto_socks5_set")]
        public int socks5_set (string? host, int port, string? username, string? password);

        /* Undefined reference to this function !?? */
        /*
        [CCode (cname = "mosquitto_userdata")]
        public void *userdata ();
        */
    }
}
