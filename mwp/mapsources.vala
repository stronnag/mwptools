
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
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
using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public struct MapSource
{
    string id;
    string name;
    int min_zoom;
    int max_zoom;
    int tile_size;
    string proj;
    string licence;
    string licence_uri;
    string uri_format;
    Champlain.MapSourceDesc desc;
}

public class MwpMapSource : Champlain.MapSourceDesc
{

    public MwpMapSource (string id,
            string name,
            string license,
            string license_uri,
            int minzoom,
            int maxzoom,
            int tile_size,
            Champlain.MapProjection projection,
            string uri_format)
    {
            /* the 0.12 vapi appears not to support projection
             * as a property 
             */
        Object(id: id, name: name, license: license, license_uri: license_uri,
               min_zoom_level: minzoom, max_zoom_level: maxzoom,
               tile_size: tile_size,
               uri_format: uri_format,
               data: (void *)projection,
               constructor: (void*)my_construct);
    }

    static Champlain.MapSource my_construct (Champlain.MapSourceDesc d)
    {
        var renderer = new Champlain.ImageRenderer();
        Champlain.MapProjection proj =  (Champlain.MapProjection)d.get_data();
        var source =  new Champlain.NetworkTileSource.full(
            d.get_id(),
            d.get_name(),
            d.get_license(),
            d.get_license_uri(),
            d.get_min_zoom_level(), 
            d.get_max_zoom_level(),
            d.get_tile_size(),
            proj,
            d.get_uri_format(),
            renderer);
        return source;
    }
}

public class JsonMapDef : Object
{
    public static MapSource[] read_json_sources(string fn)
    {
        MapSource[] sources = {};

        try {
            var parser = new Json.Parser ();
            parser.load_from_file (fn);
            var root_object = parser.get_root ().get_object ();
            foreach (var node in
                     root_object.get_array_member ("sources").get_elements ())
            {
                var s = MapSource();
                var item = node.get_object ();
                s.name = item.get_string_member ("name");
                s.id = item.get_string_member ("id");
                s.min_zoom = (int)item.get_int_member ("min_zoom");
                s.max_zoom = (int) item.get_int_member ("max_zoom");
                s.tile_size = (int)item.get_int_member("tile_size");
                s.proj = item.get_string_member("projection");
                s.uri_format = item.get_string_member("uri_format");
                s.licence = item.get_string_member("license");
                s.licence_uri = item.get_string_member("license_uri");
                sources += s;
            }
        }
        catch (Error e) {
            stderr.printf ("I guess something is not working...\n");
        }
        return sources;
    }
}
