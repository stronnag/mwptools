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

public class StrIntItem : Object {
  public string name {get;set;}
  public int id {get;set;}
  public StrIntItem(string name, int id) {
    this.name = name;
    this.id = id;
  }
}

public class StrIntStore : Object {
  public GLib.ListStore model {get; set;}
  public Gtk.SignalListItemFactory factory {get; set;}

  construct {
    model = new GLib.ListStore(typeof(StrIntItem));
    factory = new Gtk.SignalListItemFactory();
    factory.setup.connect ((f, o) => {
        Gtk.ListItem list_item =  (Gtk.ListItem)o;
        var label=new Gtk.Label("");
        list_item.set_child(label);
      });

    factory.bind.connect ((f,o) => {
        Gtk.ListItem list_item =  (Gtk.ListItem)o;
        var mi = list_item.get_item () as StrIntItem;
        var label = list_item.get_child() as Gtk.Label;
        label.set_text(mi.name);
      });
  }

  public void append(Object o) {
    model.append(o);
  }
}
