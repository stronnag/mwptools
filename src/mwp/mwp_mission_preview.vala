namespace MissionPix {
	private static Champlain.MarkerLayer mlayer;

	public string get_cached_mission_image(string mfn)
    {
        var cached = GLib.Path.build_filename(Environment.get_user_cache_dir(),
                                              "mwp");
        try
        {
            var dir = File.new_for_path(cached);
            dir.make_directory_with_parents ();
        } catch {}

        string md5name = mfn;
        if(!mfn.has_suffix(".mission"))
        {
            var ld = mfn.last_index_of_char ('.');
            if(ld != -1)
            {
                StringBuilder s = new StringBuilder(mfn[0:ld]);
                s.append(".mission");
                md5name = s.str;
            }
        }

        var chk = Checksum.compute_for_string(ChecksumType.MD5, md5name);
        StringBuilder sb = new StringBuilder(chk);
        sb.append(".png");
        return GLib.Path.build_filename(cached,sb.str);
    }

	private void temp_mission_markers(Champlain.View view,
									  Champlain.MarkerLayer markers) {
		if (mlayer == null) {
			mlayer = new Champlain.MarkerLayer();
			view.add_layer(mlayer);
		}
		if (FakeHome.is_visible) {
			var c = FakeHome.homep.get_color();
			var p = new Champlain.Point.full(MWP.conf.misciconsize, c);
			p.latitude = FakeHome.homep.latitude;
			p.longitude = FakeHome.homep.longitude;
			mlayer.add_marker(p);
		}
		var lm = markers.get_markers();
		var nm =lm.length();
		for(int i = (int)nm-1; i >= 0; i--) {
			var m = lm.nth_data(i);
			var c = ((Champlain.Label)m).get_color();
			var p = new Champlain.Point.full(MWP.conf.misciconsize, c);
			p.latitude = m.latitude;
			p.longitude = m.longitude;
			mlayer.add_marker(p);
		}
		mlayer.show();
	}

	private void remove_mission_markers() {
		mlayer.remove_all();
		mlayer.hide();
	}

	public void get_mission_pix(GtkChamplain.Embed e, Champlain.MarkerLayer? ml, string? last_file)
    {
        if(last_file != null && ml != null)
        {
            var path = get_cached_mission_image(last_file);
            var wdw = e.get_window();
            var w = wdw.get_width();
            var h = wdw.get_height();
			double dw,dh;
			if(w > h) {
				dw = 256;
				dh = 256* h / w;
			} else {
				dh = 256;
				dw = 256* w / h;
			}

			temp_mission_markers(e.champlain_view, ml);
			var ssurf = e.champlain_view.to_surface(true);
			var nsurf = new Cairo.Surface.similar (ssurf, Cairo.Content.COLOR, (int)dw, (int)dh);			var cr = new Cairo.Context(nsurf);
			cr.scale  (dw/w, dh/h);
			cr.set_source_surface(ssurf, 0, 0);
			cr.paint();
			nsurf.write_to_png(path);
			remove_mission_markers();
        }
    }
}