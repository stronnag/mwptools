/*
 * (some bits) Copyright 2023 Jonathan Hudson
 * Largely based on the Canonical source below
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/*
 * Copyright 2013 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *   Charles Kerr <charles.kerr@canonical.com>
 *   Robert Ancell <robert.ancell@canonical.com>
 */

/**
 * Bluetooth implementaion which uses org.bluez on DBus
 */
public class Bluez: Bluetooth, Object {
  uint name_watch_id = 0;
  uint next_device_id = 1;
  ObjectManager manager;
  const string BLUEZ_BUSNAME = "org.bluez";

  private bool _powered = false;

  private bool powered {
    get { return _powered; }
    set { _powered = value; update_enabled(); }
  }

  private DBusConnection bus = null;

  /* maps an org.bluez.Adapter1's object_path to the BluezAdapter proxy */
  private HashTable<ObjectPath,BluezAdapter> path_to_adapter_proxy;

  /* maps an org.bluez.Device1's object_path to the BluezDevice proxy */
  private HashTable<ObjectPath,BluezDevice> path_to_device_proxy;

  /* maps an org.bluez.Device1's object_path to our arbitrary unique id */
  private HashTable<ObjectPath,uint> path_to_id;

  /* maps our arbitrary unique id to an org.bluez.Device's object path */
  private HashTable<uint,ObjectPath> id_to_path;

  /* maps our arbitrary unique id to a Bluetooth.Device struct for public consumption */
  private HashTable<uint,BluezDev.Device> id_to_device;

  public Bluez () {
    init_bluez_state_vars ();
  }

  public void init() {
    name_watch_id = Bus.watch_name(BusType.SYSTEM,
                                   BLUEZ_BUSNAME,
                                   BusNameWatcherFlags.AUTO_START,
                                   on_bluez_appeared,
                                   on_bluez_vanished);
  }

  ~Bluez() {
    Bus.unwatch_name(name_watch_id);
  }

  private void on_bluez_appeared (DBusConnection connection, string name, string name_owner) {
	  //    debug(@"$name owned by $name_owner, setting up bluez proxies");
    bus = connection;
    init_bluez_state_vars();
    reset_manager();
  }

  private void on_bluez_vanished (DBusConnection? connection, string name)   {
	  //    debug(@"$name vanished from the bus");
	  if(connection != null) {
		  reset_bluez();
	  }
  }

  private void init_bluez_state_vars () {
    id_to_path = new HashTable<uint,ObjectPath> (direct_hash, direct_equal);
    id_to_device = new HashTable<uint,BluezDev.Device> (direct_hash, direct_equal);
    path_to_id = new HashTable<ObjectPath,uint> (str_hash, str_equal);
    path_to_adapter_proxy = new HashTable<ObjectPath,BluezAdapter> (str_hash, str_equal);
    path_to_device_proxy = new HashTable<ObjectPath,BluezDevice> (str_hash, str_equal);
  }

  private void reset_bluez () {
    init_bluez_state_vars ();

    devices_changed ();
    update_combined_adapter_state ();
    update_connected ();
    update_enabled ();
  }

  private void reset_manager() {
    try {
        manager = bus.get_proxy_sync (BLUEZ_BUSNAME, "/");
        // Find the adapters and watch for changes
        manager.interfaces_added.connect ((object_path, interfaces_and_properties) => {
          var iter = HashTableIter<string, HashTable<string, Variant>> (interfaces_and_properties);
          string name;
          while (iter.next (out name, null)) {
              if (name == "org.bluez.Adapter1")
                update_adapter (object_path);
              if (name == "org.bluez.Device1")
                update_device (object_path);
            }
        });
        manager.interfaces_removed.connect ((object_path, interfaces) => {
            foreach (var interface in interfaces) {
              if (interface == "org.bluez.Adapter1")
                adapter_removed (object_path);
              if (interface == "org.bluez.Device1")
                device_removed (object_path);
            }
        });

        var objects = manager.get_managed_objects ();
        var object_iter = HashTableIter<ObjectPath, HashTable<string, HashTable<string, Variant>>> (objects);
        ObjectPath object_path;
        HashTable<string, HashTable<string, Variant>> interfaces_and_properties;
        while (object_iter.next (out object_path, out interfaces_and_properties)) {
            var iter = HashTableIter<string, HashTable<string, Variant>> (interfaces_and_properties);
            string name;
            while (iter.next (out name, null)) {
              if (name == "org.bluez.Adapter1")
                update_adapter (object_path);
              if (name == "org.bluez.Device1")
                update_device (object_path);
            }
          }
      } catch (Error e) {
        critical (@"$(e.message)");
      }
  }

  ////
  ////  Adapter Upkeep
  ////

  private void update_adapter (ObjectPath object_path) {
	  //    debug(@"bluez5 calling update_adapter for $object_path");
    // Create a proxy if we don't have one
    var adapter_proxy = path_to_adapter_proxy.lookup (object_path);
    if (adapter_proxy == null) {
        try {
          adapter_proxy = bus.get_proxy_sync (BLUEZ_BUSNAME, object_path);
        } catch (Error e) {
          critical (@"$(e.message)");
          return;
        }
        path_to_adapter_proxy.insert (object_path, adapter_proxy);
        adapter_proxy.g_properties_changed.connect(() => update_adapter (object_path));
		changed_adapter(object_path);
	}
    update_combined_adapter_state ();
  }

  private void adapter_removed (ObjectPath object_path) {
    path_to_adapter_proxy.remove (object_path);
    update_combined_adapter_state ();
  }

  private void update_combined_adapter_state () {
    var is_discoverable = false;
    var is_powered = false;
    var is_supported = false;

    var iter = HashTableIter<ObjectPath,BluezAdapter> (path_to_adapter_proxy);
    BluezAdapter adapter_proxy;
    while (iter.next (null, out adapter_proxy)) {
        var v = adapter_proxy.get_cached_property ("Discoverable");
        if (!is_discoverable)
			is_discoverable = (v != null) && v.get_boolean ();
        v = adapter_proxy.get_cached_property ("Powered");
        if (!is_powered)
			is_powered = (v != null) && v.get_boolean ();
        is_supported = true;
	}

    discoverable = is_discoverable;
    powered = is_powered;
    supported = is_supported;
  }


  public bool discovery(bool state) {
 	  var cmd = (state) ? "StartDiscovery" : "StopDiscovery";
 	  var iter = HashTableIter<ObjectPath,BluezAdapter> (path_to_adapter_proxy);
 	  BluezAdapter adapter_proxy;
 	  ObjectPath object_path;
 	  bool resp = false;
 	  while (iter.next (out object_path, out adapter_proxy)) {
 		  try {
 			  adapter_proxy.call_sync(cmd, null, DBusCallFlags.NONE, -1, null);
 		  } catch {}
 		  resp = true;
 	  }
 	  return resp;
  }

  public ObjectPath? find_gatt_characteristic_path(uint id, string uuid) {
	  try {
		  var mpath = id_to_path.lookup (id);
		  var objects = manager.get_managed_objects ();
		  var object_iter = HashTableIter<ObjectPath, HashTable<string, HashTable<string, Variant>>> (objects);
		  ObjectPath object_path;
		  HashTable<string, HashTable<string, Variant>> interfaces_and_properties;
		  while (object_iter.next (out object_path, out interfaces_and_properties)) {
			  if ( ((string)object_path).has_prefix(mpath)) {
				  var iter = HashTableIter<string, HashTable<string, Variant>> (interfaces_and_properties);
				  string name;
				  HashTable<string, Variant> iface;
				  while (iter.next (out name, out iface)) {
					  if(name == "org.bluez.GattCharacteristic1") {
						  var cuuid = iface.get("UUID").get_string();
						  if(cuuid == uuid) {
							  return object_path;
						  }
					  }
				  }
			  }
		  }
	  } catch (Error e) {
		  print("om : %s\n", e.message);
	  }
	  return null;
  }

  public bool find_service(uint id, string uuid) {
	  var path = id_to_path.lookup (id);
	  try {
		  var objects = manager.get_managed_objects ();
		  var object_iter = HashTableIter<ObjectPath, HashTable<string, HashTable<string, Variant>>> (objects);
		  ObjectPath object_path;
		  HashTable<string, HashTable<string, Variant>> interfaces_and_properties;
		  while (object_iter.next (out object_path, out interfaces_and_properties)) {
			  var iter = HashTableIter<string, HashTable<string, Variant>> (interfaces_and_properties);
			  string name;
			  HashTable<string, Variant> iface;
			  while (iter.next (out name, out iface)) {
				  if(name == "org.bluez.GattService1") {
					  var suuid = iface.get("UUID").get_string();
					  var devp = iface.get("Device").get_string();
					  if(suuid == uuid && devp == path) {
						  return true;
					  }
				  }
			  }
		  }
	  } catch (Error e) {
		  print("om : %s\n", e.message);
	  }
	  return false;
  }


  /**
  ////
  ////  bluetooth device UUIDs
  ////

  private static uint16 get_uuid16_from_uuid_string (string uuid) {
    uint16 uuid16;

    string[] tokens = uuid.split ("-", 1);
    if (tokens.length > 0)
      uuid16 = (uint16) uint64.parse ("0x"+tokens[0]);
    else
      uuid16 = 0;

    return uuid16;
  }
  **/

  ////
  ////  Device Upkeep
  ////

  /* Update our public Device struct from the org.bluez.Device's properties.
   *
   * This is called when we first walk through bluez' Devices on startup,
   * when the org.bluez.Adapter gets a new device,
   * and when a device's properties changes, we need to rebuild the proxy.
   */
  private void update_device (ObjectPath object_path) {
	  //	  debug(@"bluez5 calling update_device for $object_path");

    // Create a proxy if we don't have one
	  var device_proxy = path_to_device_proxy.lookup (object_path);
	  if (device_proxy == null) {
		  try {
			  device_proxy = bus.get_proxy_sync (BLUEZ_BUSNAME, object_path);
		  } catch (Error e) {
			  critical (@"$(e.message)");
			  return;
		  }
		  path_to_device_proxy.insert (object_path, device_proxy);
		  device_proxy.g_properties_changed.connect(() => update_device (object_path));
      }

    // look up our id for this device.
    // if we don't have one yet, create one.
	  var id = path_to_id.lookup (object_path);
	  if (id == 0) {
		  id = next_device_id ++;
		  id_to_path.insert (id, object_path);
		  path_to_id.insert (object_path, id);
      }

    // look up the device's type
	  BluezDev.Device.Type type;
	  var v = device_proxy.get_cached_property ("Class");
	  if (v == null)
		  type = BluezDev.Device.Type.OTHER;
	  else
		  type = BluezDev.Device.class_to_device_type (v.get_uint32());

    // look up the device's human-readable name
	  v = device_proxy.get_cached_property ("Alias");
	  if (v == null)
		  v = device_proxy.get_cached_property ("Name");
	  var name = v == null ? "Unknown" : v.get_string ();

    // look up the device's bus address
	  v = device_proxy.get_cached_property ("Address");
	  var address = v == null ? null : v.get_string ();

    // look up the device's Connected flag
	  v = device_proxy.get_cached_property ("Connected");
	  var is_connected = (v != null) && v.get_boolean ();

	  v = device_proxy.get_cached_property ("RSSI");
	  int16 rssi = 0;
	  if  (v != null)
		  rssi = v.get_int16 ();

	/**
    // derive the uuid-related attributes we care about
    v = device_proxy.get_cached_property ("UUIDs");
    uint16[] uuids = {};
    if (v != null) {
	string[] uuid_strings = v.dup_strv ();
	foreach (var s in uuid_strings)
	uuids += get_uuid16_from_uuid_string (s);
    }
	**/
	  id_to_device.insert (id, new BluezDev.Device (id,
													type,
													name,
													address,
													rssi,
													is_connected));
	  devices_changed ();
	  update_connected ();
	  changed_device(id);
  }

  private void device_removed (ObjectPath path) {
    var id = path_to_id.lookup (path);
	removed_device(id);
    path_to_id.remove (path);
    id_to_path.remove (id);
    id_to_device.remove (id);
    devices_changed ();
  }

  void update_enabled () {
	  //	  debug (@"in upate_enabled, powered is $powered");
	  enabled = powered;
  }

  private bool have_connected_device () {
    var devices = get_devices();
    foreach (var device in devices)
      if (device.is_connected)
        return true;
    return false;
  }

  private void update_connected () {
    connected = have_connected_device ();
  }

  ////
  ////  Public API
  ////

  public BluezDev.Device? get_device(uint id) {
	  return id_to_device.lookup (id);
  }

  public uint get_id_for(string addr_or_name) {
	  var devices = get_devices();
	  foreach (var device in devices) {
		  if(device.address == addr_or_name) {
			  return device.id;
		  }
		  if(device.name == addr_or_name) {
			  return device.id;
		  }
	  }
	  return 0;
  }

  public Variant? get_device_property(uint id, string property) {
	  var device = id_to_device.lookup (id);
	  var path = id_to_path.lookup (id);
	  var proxy = (path != null) ? path_to_device_proxy.lookup (path) : null;
	  if (device != null) {
		  var v = proxy.get_cached_property (property);
		  return v;
	  }
	  return null;
  }

  public bool set_device_connected (uint id, bool connected) {
	  bool ok = true;
	  var device = id_to_device.lookup (id);
	  var path = id_to_path.lookup (id);
	  var proxy = (path != null) ? path_to_device_proxy.lookup (path) : null;

	  if ((device != null) && (device.is_connected != connected)) {
		  try {
			  if (connected)
				  proxy.connect_ ();
			  else
				  proxy.disconnect_ ();
		  } catch (Error e) {
			  ok = false;
		  }
		  update_connected ();
	  }
	  return ok;
  }

  public void try_set_discoverable (bool b) {
    if (discoverable != b) {
        var iter = HashTableIter<ObjectPath,BluezAdapter> (path_to_adapter_proxy);
        ObjectPath object_path;
        BluezAdapter adapter_proxy;
        while (iter.next (out object_path, out adapter_proxy))
          adapter_proxy.call.begin ("org.freedesktop.DBus.Properties.Set",
                                    new Variant ("(ssv)", "org.bluez.Adapter1", "Discoverable", new Variant.boolean (b)),
                                    DBusCallFlags.NONE, -1);
      }
  }

  public List<unowned BluezDev.Device> get_devices () {
    return id_to_device.get_values();
  }

  public bool supported { get; protected set; default = false; }
  public bool discoverable { get; protected set; default = false; }
  public bool enabled { get; protected set; default = false; }
  public bool connected { get; protected set; default = false; }

  public void try_set_enabled (bool b) {
	  var iter = HashTableIter<ObjectPath,BluezAdapter> (path_to_adapter_proxy);
	  ObjectPath object_path;
	  BluezAdapter adapter_proxy;
	  while (iter.next (out object_path, out adapter_proxy))
          adapter_proxy.call.begin ("org.freedesktop.DBus.Properties.Set",
                                    new Variant ("(ssv)", "org.bluez.Adapter1", "Powered", new Variant.boolean (b)),
                                    DBusCallFlags.NONE, -1);
  }
}

[DBus (name = "org.freedesktop.DBus.ObjectManager")]
private interface ObjectManager : Object {
	[DBus (name = "GetManagedObjects")]
	public abstract HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> get_managed_objects() throws DBusError, IOError;

	[DBus (name = "InterfacesAdded")]
	public signal void interfaces_added(ObjectPath object_path, HashTable<string, HashTable<string, Variant>> interfaces_and_properties);

	[DBus (name = "InterfacesRemoved")]
	public signal void interfaces_removed(ObjectPath object_path, string[] interfaces);
}

[DBus (name = "org.bluez.Adapter1")]
private interface BluezAdapter : DBusProxy {
}

[DBus (name = "org.bluez.Device1")]
private interface BluezDevice : DBusProxy {
	[DBus (name = "Connect")]
	public abstract void connect_() throws DBusError, IOError;

	[DBus (name = "Disconnect")]
	public abstract void disconnect_() throws DBusError, IOError;
}
