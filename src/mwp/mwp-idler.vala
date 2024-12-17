namespace MwpIdle {

#if UNIX
	public void uninhibit(uint cookie) {
		Mwp.window.application.uninhibit(cookie);
		Mwp.dtnotify.send_notification("mwp", "Unhibit screen/idle/suspend");
	}

	public uint inhibit() {
		uint cookie = Mwp.window.application.inhibit(Mwp.window, Gtk.ApplicationInhibitFlags.IDLE|Gtk.ApplicationInhibitFlags.SUSPEND,"mwp telem");
		Mwp.dtnotify.send_notification("mwp", "Unhibit screen/idle/suspend");
		return cookie;
	}
#else
	public void uninhibit(uint cookie) {
		WinIdle.uninhibit(cookie);
	}

	public uint inhibit() {
		uint cookie = WinIdle.inhibit();
		return cookie;
	}
#endif
}
