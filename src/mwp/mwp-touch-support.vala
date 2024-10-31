namespace Touch {
	internal int8 is_touch = -1;
	public bool has_touch_screen() {
		if (is_touch == -1) {
			var dp = Gdk.Display.get_default();
			var seat = dp.get_default_seat();
			var cap = seat.get_capabilities();
			is_touch = (int8)(cap & Gdk.SeatCapabilities.TOUCH);
		}
		return (bool)is_touch;
	}
}
