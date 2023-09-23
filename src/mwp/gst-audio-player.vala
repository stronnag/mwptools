using Gst;

public class AudioPlayer {
	public static void play(string filename) {
		var pipeline = ElementFactory.make ("playbin", "player");
		var bus = pipeline.get_bus ();
		bus.add_watch (0, (b, message) => {
				switch (message.type) {
				case MessageType.ERROR:
				GLib.Error err;
				string debug;
				message.parse_error (out err, out debug);
				MWPLog.message ("Audio: %s\n", err.message);
				break;
				case MessageType.EOS:
				pipeline.set_state (State.NULL);
				b.remove_watch();
				pipeline = null;
				bus = null;
				return false;

				default:
				break;
				}
				return true;
			});

		try {
			var uri = Gst.filename_to_uri(filename);
			pipeline.set("uri", uri);
			pipeline.set_state(Gst.State.PLAYING);
		} catch {
			MWPLog.message("Audio: Failed to open %s\n", filename);
		}
	}
}

#if TEST
namespace MWPLog {
	public static void message(string format, ...) {
		var args = va_list();
        stderr.vprintf(format, args);
        stderr.flush();
    }
}

public static int main (string[] args) {
	Gst.init (ref args);
	var n = 0;
	var loop = new GLib.MainLoop();
	Idle.add (() => {
			print("loop %d\r", n++);
			AudioPlayer.play(args[1]);
			Timeout.add_seconds(1, () => {
					print("loop %d\r", n++);
					AudioPlayer.play(args[1]);
					return true;
				});
			return false;
		});
	loop.run(/* */);
	return 0;
}
#endif
