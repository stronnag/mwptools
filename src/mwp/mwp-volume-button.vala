
namespace Utils {
	public class VolumeButton : Gtk.ScaleButton {
		const string[]symbols={"audio-volume-low-symbolic", "audio-volume-high-symbolic", "audio-volume-medium-symbolic"};
		public VolumeButton() {
			Object(icons: symbols);
			var a = new Gtk.Adjustment(0.5, 0, 1, 0.01, 0.1, 0);
			this.set_adjustment(a);
		}
	}
}
