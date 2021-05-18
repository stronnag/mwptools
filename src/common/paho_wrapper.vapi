[CCode(cheader_filename = "paho_wrapper.h")]
namespace MQTT {
    [CCode (cname = "void", free_function = "paho_wrapper_cleanup", has_type_id = false)]
    [Compact]
    public class Client  {
        [CCode(cname = "paho_wrapper_setup")]
        public Client (string uri, string? cafile);
        [CCode(cname="paho_wrapper_subscribe")]
        public int subscribe(string topic);
        [CCode(cname="paho_wrapper_unsubscribe")]
        public int unsubscribe(string topic);
        [CCode(cname="paho_wrapper_disconnect")]
        public void disconnect();
        [CCode(cname="paho_wrapper_poll_message")]
        public int poll_message(out string? msg);
    }
    [CCode(cname="paho_wrapper_last_error")]
    public static int connect_status();
}
