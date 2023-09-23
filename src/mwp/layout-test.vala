/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */
using Xml;

class LayoutTester : Object {
    public int ncount;

    public int read_xml_file(string path) {
        Parser.init ();
        Xml.Doc* doc = Parser.parse_file (path);
        if (doc == null) {
            stderr.printf ("File %s not found or permissions missing\n", path);
            return -1;
        }
        Xml.Node* root = doc->get_root_element ();
        if (root != null) {
            if (root->name.down() == "dock-layout") {
                parse_node (root);
            }
        }
        delete doc;
        Parser.cleanup();
        return ncount;
    }

    private void parse_node (Xml.Node* node) {
        for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
            if (iter->type != ElementType.ELEMENT_NODE) {
                continue;
            }
            switch(iter->name.down()) {
                case  "layout":
                    for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
                        string attr_content = prop->children->content;
                        switch( prop->name) {
                            case "name":
                                if(attr_content == "mwp") {
                                    ncount = 0;
                                    parse_node(iter);
                                }
                                break;
                        }
                    }
                    break;
                case "dock":
                case "paned":
                    parse_node(iter);
                    break;

                case "item":
                    ncount++;
                    break;
            }
        }
    }
}
