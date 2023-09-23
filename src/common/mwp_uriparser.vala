/*
  Transcribed from: https://rosettacode.org/wiki/URL_parser#Wren
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
#if USE_URIPARSE
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
#else
		var index = url.index_of("//");
		if (index >= 0 && url[index-1] == ':') {
			var parts = url.split("//");
			u.scheme = parts[0][0:parts[0].length-1];

			var domain = parts[1].split("/");
			if (domain[0].contains("@")) {
				var cred = domain[0].split("@");
				string []split = {cred[0], ""};
				if (cred[0].contains(".")) {
					split = cred[0].split(".");
				} else if (cred[0].contains(":")) {
					split = cred[0].split(":");
				}
				u.user = split[0];
				u.passwd = split[1];
				if (cred[1].contains(":")) {
					split = cred[1].split(":");
					u.host = split[0];
					u.port = int.parse(split[1]);
				} else {
					u.host = cred[1];
					u.port = -1;
				}
			} else if (domain[0].contains(":") && !domain[0].contains("[")
					   && !domain[0].contains("]")) {
				var split = domain[0].split(":");
				u.host = split[0];
				u.port = int.parse(split[1]);
			} else if (domain[0].contains("[") && domain[0].contains("]:")) {
				var split = domain[0].split("]");
				u.host = split[0] + "]";
				u.port = int.parse(split[1]);
			} else {
				u.host = domain[0];
			}

			// parse the path if it exists
			if (domain.length > 1) {
				u.path = "/";
				for (var i =1; i < domain.length; i++) {
					if (i < domain.length - 1) {
						u.path = u.path + domain[i] + "/";
					} else if (domain[i].contains("?")) {
						var split = domain[i].split("?");
						u.path = u.path + split[0];
						if (domain[i].contains("#")) {
							var split2 = split[1].split("#");
							u.query = split2[0];
							u.fragment = split2[1];
						} else {
							u.query = split[1];
						}
					} else if (domain[i].contains("#")) {
						var split = domain[i].split("#");
						u.fragment = split[1];
					} else {
						u.path = u.path + domain[i];
					}
				}
			}
			return u;
		} else if (url.contains(":")) {
			index = url.index_of(":");
			u.scheme = url[0:index];
			u.path = url[index+1:url.length];
			if (u.path.contains("?")) {
				var split = u.path.split("?");
				u.query = split[1];
				u.path = split[0];
				if (u.query.contains("#")) {
					split = u.query.split("#");
					u.fragment = split[1];
					u.query=split[0];
				}
			}
			return u;
		} else {
			return null;
		}
#endif
	}
}

#if TEST
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
