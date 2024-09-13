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
 */

namespace Img {
	public Gdk.Pixbuf? load_image_from_file(string fn,int w=-1,int h=-1) throws GLib.Error {        try {
			var iconfile = MWPUtils.find_conf_file(fn, "pixmaps");
			var pix = new Gdk.Pixbuf.from_file(iconfile);
			if (w > 0 || h > 0) {
				pix = ((Gdk.Pixbuf)pix).scale_simple(w, h,Gdk.InterpType.BILINEAR);
			}
			return pix;
        } catch {
			MWPLog.message("failed to find icon %s\n", fn);
		}
		return null;
    }
}

namespace Gis {
	Shumate.SimpleMap simple;
	Shumate.Map map;
	Gtk.Overlay overlay;
	Shumate.MapLayer? base_layer;
	Shumate.PathLayer hp_layer;
	Shumate.PathLayer mp_layer;
	Shumate.MarkerLayer info_layer;
	Shumate.MarkerLayer rm_layer;
	Shumate.MarkerLayer mm_layer;
	Shumate.MarkerLayer hm_layer;
	Shumate.MarkerLayer tt_layer;
	private StrIntStore mis;
	internal Queue<Shumate.MapLayer?> qml;
	private Gtk.Label warnlab;
	private Gtk.Label osdlab;


	public void init () {
		Gis.simple = new Shumate.SimpleMap();
		Gis.map = Gis.simple.map;
		Gis.simple.show_zoom_buttons = false;
		Gis.simple.vexpand = true;
		Gis.base_layer = null;
		qml = new  Queue<Shumate.MapLayer?>();
		Gis.overlay = new Gtk.Overlay();
		Gis.overlay.set_child(Gis.simple);
		warnlab = new Gtk.Label("");
		warnlab.use_markup = true;
		osdlab = new Gtk.Label("");
		osdlab.use_markup = true;
		warnlab.halign = Gtk.Align.START;
		warnlab.valign = Gtk.Align.START;
		osdlab.halign = Gtk.Align.START;
		osdlab.valign = Gtk.Align.START;
		Gis.overlay.add_overlay(warnlab);
		Gis.overlay.add_overlay(osdlab);
	}

	public void  map_show_warning(string msg) {
		warnlab.label = "<span size='300%%' color='#ff0000c0'>%s</span>".printf(msg);
		warnlab.show();
	}

	public void  map_hide_warning() {
		warnlab.hide();
		warnlab.label="";
	}

	public void  map_show_osd(string msg) {
		var parts = Mwp.conf.wp_text.split("/");
		osdlab.label = "<span font='%s' color='%s'>%s</span>".printf(parts[0], parts[1], msg);
		osdlab.show();
	}

	public void  map_hide_osd() {
		osdlab.hide();
		osdlab.label="";
	}

	public Shumate.MapSourceRegistry setup_registry() {
		string? msfn = null;
		if(Mwp.conf.map_sources != null && Mwp.conf.map_sources != "") {
            msfn = MWPUtils.find_conf_file(Mwp.conf.map_sources);
		}

		MapIdCache.init();
		var mr = new Shumate.MapSourceRegistry.with_defaults ();
		var mss = MapManager.read_json_sources(msfn);
		foreach(var d in mss) {
			var ds = add_source(d);
			mr.add(ds);
			var cname = MapIdCache.normalise(d.url_template);
			MapIdCache.cache.insert(d.id, {cname, d.url_template});
		}
		return mr;
	}

	private Shumate.MapSource add_source(MwpMapDesc md) {
        var ms = new Shumate.RasterRenderer.full_from_url(
            md.id,
            md.name,
			md.license,
			md.license_uri,
			md.min_zoom_level,
			md.max_zoom_level,
			md.tile_size,
			md.projection,
			md.url_template);
        return ms;
	}

	public string[]get_map_names() {
		string[] sl={};
		for(var j = 0; j < mis.model.get_n_items(); j++) {
			sl += ((StrIntItem)mis.model.get_item(j)).name;
		}
		return sl;
	}

	public void setup_map_sources(Gtk.DropDown mapdrop) {
		var mr = setup_registry();
		mis = new StrIntStore();
		var ditem = 0;
		var nitem = 0;
		var nn = 0;
		var item = Mwp.conf.defmap;
		for(var j = 0; j < mr.get_n_items(); j++) {
			var ms = mr.get_item(j) as Shumate.MapSource;
			if(ms.id.has_prefix("owm")) {
				continue;
			}
			var name = ms.name;
			if(name.contains("OpenStreetMap"))
				name = name.replace("OpenStreetMap","OSM");
			if (name == item || ms.name == item) {
				ditem = nn;
				nitem = j;
			}
			nn++;
			mis.append(new StrIntItem(name, j));
		}

		var ms = mr.get_item(nitem) as Shumate.MapSource;
		Gis.base_layer = new Shumate.MapLayer(ms, Gis.map.viewport);
		Gis.map.add_layer(Gis.base_layer);
		Gis.map.set_map_source (ms);
		Gis.simple.license.append_map_source(ms);
		qml.push_tail(Gis.base_layer);

		Gis.map.center_on(Mwp.conf.latitude, Mwp.conf.longitude);
		Gis.map.viewport.set_zoom_level( Mwp.conf.zoom);
		Gis.info_layer = new Shumate.MarkerLayer(Gis.map.viewport); // radar markers
		Gis.map.add_layer(Gis.info_layer);

		Gis.hp_layer = new Shumate.PathLayer(Gis.map.viewport); // Mission marker
		Gis.map.add_layer(Gis.hp_layer);
		Gis.mp_layer = new Shumate.PathLayer(Gis.map.viewport); // Mission marker
		Gis.map.add_layer(Gis.mp_layer);
		Gis.rm_layer = new Shumate.MarkerLayer(Gis.map.viewport); // radar markers
		Gis.map.add_layer(Gis.rm_layer);
		Gis.mm_layer = new Shumate.MarkerLayer(Gis.map.viewport); // Mission marker
		Gis.map.add_layer(Gis.mm_layer);
		Gis.hm_layer = new Shumate.MarkerLayer(Gis.map.viewport); // home marker
		Gis.map.add_layer(Gis.hm_layer);
		Gis.tt_layer = new Shumate.MarkerLayer(Gis.map.viewport); // Tips
		Gis.map.add_layer(Gis.tt_layer);
		var c = Gdk.RGBA();
		c.parse("red");
		Gis.mp_layer.set_stroke_color(c);
		Gis.mp_layer.set_stroke_width(4);

		mapdrop.set_model(mis.model);
		mapdrop.set_factory(mis.factory);
		mapdrop.set_selected(ditem);

		mapdrop.notify["selected"].connect(() => {
				var mi = mapdrop.get_selected_item() as StrIntItem;
				var msl =  mr.get_item(mi.id) as Shumate.MapSource;
				if(msl != null) {
					Shumate.MapLayer? xbl=qml.peek_tail();
					Gis.simple.license.remove_map_source(xbl.map_source);
					Gis.base_layer = new Shumate.MapLayer(msl, Gis.map.viewport);
					Gis.map.insert_layer_above(Gis.base_layer, xbl);
					qml.push_tail(Gis.base_layer);
					Gis.simple.license.append_map_source(msl);
					Gis.map.set_map_source (msl);
					cleanup_qml();
				}
			});
	}

	private void cleanup_qml() {
		var qn = qml. get_length ();
		for(var j = 2; j < qn; j++) {
			var _ml = qml.pop_head();
			if (_ml != null) {
				Gis.map.remove_layer(_ml);
			}
		}
	}
}
