[CCode(cheader_filename = "mwp-gatt-bridge.h",  cname="gattclient_t", free_function="mwp_gatt_close", has_type_id = false)]
[Compact]
public class GattClient {
	[CCode (cname = "new_mwp_gatt")]
	public GattClient(string? addr, out int status);
	[CCode (cname = "mwp_gatt_bridge")]
	public void bridge();
	[CCode (cname = "mwp_gatt_devnode")]
	public unowned string get_devnode();
}
