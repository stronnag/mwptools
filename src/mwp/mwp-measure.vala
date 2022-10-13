class MeasureLayer : Object {
    private Champlain.PathLayer pl;
    private Champlain.MarkerLayer ml;
    private Clutter.Color ycol;
    private double td;
    private bool measure;

    public MeasureLayer(Gtk.Window w, Champlain.View view) {
        pl = new Champlain.PathLayer();
        ml = new Champlain.MarkerLayer();
        ycol = {0xf, 0x0f, 0xf, 0xa0};
        pl.set_stroke_color(ycol);
        pl.set_stroke_width (2);
        measure = false;
        view.button_release_event.connect ((event) => {
                double lat, lon;
                if (event.button == 1) {
                    if(measure) {
                        lat = view.y_to_latitude (event.y);
                        lon = view.x_to_longitude (event.x);
                        add(lat, lon);
                    }
                }

                if(event.button == 2) {
                    if(measure) {
                        popup(w, view);
                      }
                  }
                return false;
            });
    }

    public void toggle_state(Gtk.Window w, Champlain.View view, int ex, int ey) {
        if (measure) {
            popup(w, view);
        } else {
            measure = true;
            view.add_layer(pl);
            view.add_layer(ml);
            var lat = view.y_to_latitude (ey);
            var lon = view.x_to_longitude (ex);
            add(lat, lon);
          }
    }

    public void add(double lat, double lon) {
        Champlain.Marker l;
        try {
            float w,h;
            Clutter.Actor actor = new Clutter.Actor ();
			var img = MWPMarkers.load_image_from_file("dist.svg", 20, 20);
            img.get_preferred_size(out w, out h);
			actor.set_size((int)w, (int)h);
			actor.content = img;
			l = new MWPLabel.with_image(actor);
            ((Champlain.Label)l).set_draw_background (false);
            l.set_pivot_point(0.5f, 0.5f);
        } catch {
            l = new Champlain.Point();
            ((Champlain.Point)l).color = ycol;
        }
        l.latitude = lat;
        l.longitude = lon;
        l.set_draggable(true);
        pl.add_node(l);
        ml.add_marker(l);
    }

    public void  calc_distance() {
        double llat = 0;
        double llon = 0;
        double lat = 0;
        double lon = 0;
        bool calc = false;

        td = 0.0;

        foreach(var n in pl.get_nodes()) {
            lon = ((Champlain.Point)n).longitude;
            lat = ((Champlain.Point)n).latitude;
            if(calc) {
                double c;
                double d;
                Geo.csedist(llat,llon,lat,lon, out d, out c);
                td += d;
            }
            llat = lat;
            llon = lon;
            calc = true;
        }
    }

    public void popup(Gtk.Window w, Champlain.View view) {
        var dlg = new Gtk.Dialog.with_buttons ("Measurement", w, 0,
                                               "Continue", Gtk.ResponseType.OK,
                                               "Close", Gtk.ResponseType.CLOSE);
        dlg.set_position(Gtk.WindowPosition.MOUSE);
        dlg.set_keep_above(true);
        dlg.response.connect((resp) => {
//                print("DBG: RESP  %s\n", ((Gtk.ResponseType)resp).to_string());
                switch (resp) {
                case Gtk.ResponseType.OK:
                    break;
                case Gtk.ResponseType.CLOSE:
                    measure = false;
                    break;
                default:
                    if(!measure) {
                        pl.remove_all();
                        ml.remove_all();
                        view.remove_layer(pl);
                        view.remove_layer(ml);
                    }
                    break;
                }
                dlg.close();
            });
        var content = dlg.get_content_area ();
        calc_distance();
        var label = new Gtk.Label("Distance %.1fm (%.1fnm)".printf(td*1852.0, td));
        content.pack_start (label, false, false, 0);
        dlg.show_all();
    }

    public bool is_active() {
        return measure;
    }
}
