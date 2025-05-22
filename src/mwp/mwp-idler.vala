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

namespace MwpIdle {

#if UNIX
	public void uninhibit(uint cookie) {
		Mwp.window.application.uninhibit(cookie);
		Mwp.dtnotify.send_notification("mwp", "Unhibit screen/idle/suspend");
	}

	public uint inhibit() {
		uint cookie = Mwp.window.application.inhibit(Mwp.window, Gtk.ApplicationInhibitFlags.IDLE|Gtk.ApplicationInhibitFlags.SUSPEND,"mwp telem");
		Mwp.dtnotify.send_notification("mwp", "Unhibit screen/idle/suspend");
		return cookie;
	}
#else
	public void uninhibit(uint cookie) {
		WinIdle.uninhibit(cookie);
	}

	public uint inhibit() {
		uint cookie = WinIdle.inhibit();
		return cookie;
	}
#endif
}
