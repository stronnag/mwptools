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
        string query;
        string fragment;
        string scheme;
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
            u.query = up.get_query();
            u.scheme = up.get_scheme();
            u.fragment = up.get_fragment();
        } catch {
            return null;
        }
		return u;
	}
}

#if TEST
/*
  Transcribed from: https://rosettacode.org/wiki/URL_parser#Wren
*/
public static int main(string?[] args) {
	string[] urls;
	if (args.length > 1) {
		urls = args[1:args.length];
	} else {
		urls = {
			"foo://example.com:8042/over/there?name=ferret#nose",
			"urn:example:animal:ferret:nose",
			"jdbc:mysql://test_user:ouupppssss@localhost:3306/sakila?profileSQL=true",
			"ftp://ftp.is.co.za/rfc/rfc1808.txt",
			"http://www.ietf.org/rfc/rfc2396.txt#header1",
			"ldap://[2001:db8::7]/c=GB?objectClass=one&objectClass=two",
			"mailto:John.Doe@example.com",
			"news:comp.infosystems.www.servers.unix",
			"tel:+1-816-555-1212",
			"telnet://192.0.2.16:80/",
			"urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
			"ssh://alice@example.com",
			"https://bob:pass@example.com/place",
			"""http://example.com/?a=1&b=2+2&c=3&c=4&d=\%65\%6e\%63\%6F\%64\%65\%64"""
		};
	}

	foreach(var url in urls) {
		print("Parsing %s ...\n", url);
		var u = UriParser.parse(url);
		if (u != null) {
			if(u.scheme != null)
				print("\tscheme = %s\n", u.scheme);
			if(u.user != null)
			print("\tuser = %s\n", u.user);
			if(u.passwd != null)
				print("\tpassword = %s\n", u.passwd);
			if(u.host != null)
				print("\thost = %s\n", u.host);
			if(u.port != -1)
				print("\tport = %d\n", u.port);
			if(u.path != null)
				print("\tpath = %s\n", u.path);
			if(u.fragment != null)
				print("\tfragment = %s\n", u.fragment);
			if(u.query != null)
				print("\tquery = %s\n", u.query);
		} else {
			print("** Invalid**\n");
		}
	}
	return 0;
}
#endif
