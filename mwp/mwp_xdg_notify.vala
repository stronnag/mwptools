[DBus (name = "org.freedesktop.Notifications")]
interface DTNotify : Object {
    public abstract uint Notify(
	string app_name,
 	uint replaces_id,
 	string app_icon,
 	string summary,
 	string body,
        string[]? actions,
 	HashTable<string,Variant>? hints,
 	int expire_timeout) throws GLib.DBusError, GLib.IOError;
}

public class MwpNotify : GLib.Object
{
    private DTNotify dtnotify;
    private HashTable<string, Variant> _ht;
    private bool is_valid = false;

    public MwpNotify()
    {
        try
        {
            dtnotify = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.Notifications",
                                     "/org/freedesktop/Notifications");
            _ht = new HashTable<string, uint8>(null,null);
            _ht.insert ("urgency", 0);
            is_valid = true;
        } catch {
            is_valid = false;
        }
    }
    public void send_notification(string summary,  string text)
    {
        try
        {
            if (is_valid)
                dtnotify.Notify ("mwp",0,"mwp_icon", summary, text, null, _ht, 5000);
        } catch {
            is_valid = false;
        }
    }
}
