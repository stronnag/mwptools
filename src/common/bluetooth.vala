 /*
  * (some bits) Copyright 2023 Jonathan Hudson
  * Largely based on the Canonical source below
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
  */


 /**
  * Abstract interface for the Bluetooth backend.
  */
 public interface Bluetooth: Object {
   /* True if there are any bluetooth adapters on this system.
	  This work as a proxy for "does this hardware support bluetooth?" */
   public abstract bool supported { get; protected set; }

   /* True if bluetooth's enabled on this system.
	  Bluetooth can be soft-blocked by software and hard-blocked physically,
	  eg by a laptop's network killswitch */
   public abstract bool enabled { get; protected set; }

   /* True if we have a connected device. */
   public abstract bool connected { get; protected set; }

   /* Try to enable/disable bluetooth. This can fail if it's overridden
	  by the system, eg by a laptop's network killswitch */
   public abstract void try_set_enabled (bool b);

   /* True if our system can be seen by other bluetooth devices */
   public abstract bool discoverable { get; protected set; }
   public abstract void try_set_discoverable (bool discoverable);

   /* Get a list of the BTDevice structs that we know about */
   public abstract List<unowned BluezDev.Device> get_devices ();

   /* Emitted when one or more of the devices is added, removed, or changed */
   public signal void devices_changed ();
   public signal void added_device(uint id);
   public signal void removed_device(uint id);

   /* Try to connect/disconnect a particular device.
	  The device_key argument comes from the BTDevice struct */
   public abstract bool set_device_connected (uint device_key, bool connected);
 }
