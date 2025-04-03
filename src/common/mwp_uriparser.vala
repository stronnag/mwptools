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

namespace UriParser {
	public struct UriParts {
		string host;
        string path;
        int port;
        string user;
        string passwd;
		HashTable<string, string?> qhash;
        string fragment;
        string scheme;

		public string to_string() {
			StringBuilder sb = new StringBuilder();
			if(scheme != null)
				sb.append_printf("\tscheme = %s\n", scheme);
			if(user != null)
				sb.append_printf("\tuser = %s\n", user);
			if(passwd != null)
				sb.append_printf("\tpassword = %s\n", passwd);
			if(host != null)
				sb.append_printf("\thost = %s\n", host);
			if(port != -1)
				sb.append_printf("\tport = %d\n", port);
			if(path != null)
				sb.append_printf("\tpath = %s\n", path);
			if(fragment != null)
				sb.append_printf("\tfragment = %s\n", fragment);
			if(qhash != null) {
				List <unowned string> lk = qhash.get_keys();
				for(unowned var lp = lk.first(); lp != null; lp = lp.next) {
					var key = lp.data;
					var val = qhash.get(key);
					sb.append_printf("\tquery %s = %s\n", key, val);
				}
			}
			return sb.str;
		}
	}

	public UriParts? parse(string url) {
		UriParts u = {};
        try {
            var up = Uri.parse(url, UriFlags.HAS_PASSWORD);
            u.host = up.get_host();
            u.port = up.get_port();
            u.path = up.get_path();
            u.user = up.get_user();
            u.passwd = up.get_password();
            u.scheme = up.get_scheme();
            u.fragment = up.get_fragment();
			if(up.get_query() != null) {
				u.qhash = new HashTable<string, string?> (str_hash, str_equal);
				var parts = up.get_query().split("&");
				foreach (var p in parts) {
					var q = p.split("=");
					string? qv;
					if(q.length > 1) {
						qv = q[1];
					} else {
						qv = null;
					}
					u.qhash.insert(q[0], qv);
				}
			} else {
				u.qhash = null;
			}
        } catch {
            return null;
        }
		return u;
	}

	public UriParts? dev_parse(string url) {
		var u = UriParser.parse(url);
		if (u != null) {
			return u;
		} else {
			var ds = "tty:%s".printf(url);
			u = UriParser.parse(ds);
			return u;
		}
	}
}
