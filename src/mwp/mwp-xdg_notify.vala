/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

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

public class MwpNotify : GLib.Object {
    private DTNotify dtnotify;
    private HashTable<string, Variant> _ht;
    private bool is_valid = false;

    public MwpNotify() {
        try {
            dtnotify = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.Notifications",
                                     "/org/freedesktop/Notifications");
            _ht = new HashTable<string, uint8>(null,null);
            _ht.insert ("urgency", 0);
            is_valid = true;
        } catch {
            is_valid = false;
        }
    }
    public void send_notification(string summary,  string text) {
        try {
            if (is_valid)
                dtnotify.Notify ("mwp",0,"mwp_icon", summary, text, null, _ht, 5000);
        } catch {
            is_valid = false;
        }
    }
}
