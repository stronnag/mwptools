
extern void *create_win_process(char *cmd, int flags, int *spipe, int *epipe, int32 *pid);
extern void waitproc(void *h);
extern int32 get_pid(void* h);
extern void kill (int32 pid);

public class ProcessLauncher : Object {
	private int spipe;
	private int epipe;
	private int32 pid;
	public int get_stdout_pipe() {
		return spipe;
	}
	public int get_stderr_pipe() {
		return epipe;
	}

	public IOChannel get_stdout_iochan() {
		return new IOChannel.win32_new_fd(spipe);
	}

	public IOChannel get_stderr_iochan() {
		return new IOChannel.win32_new_fd(epipe);
	}

	public signal void complete();
	public bool run(string[]? argv, int flag) {
		var sb = new StringBuilder();
		foreach(var a in argv) {
			if(a.contains(" ")) {
				sb.append_c('"');
			}
			sb.append(a);
			if(a.contains(" ")) {
				sb.append_c('"');
			}
			sb.append_c(' ');
		}
		var cmd = sb.str.strip();
		spipe=-1;
		epipe=-1;

		var res = create_win_process(cmd, flag, &spipe, &epipe, &pid);
		if (res != null) {
			new Thread<bool>("wwait", () => {
				waitproc(res);
				windone();
				return true;
			});
		}
		return (res != null);
	}

	private void windone() {
		Idle.add(() => {
				complete();
				return false;
			});
	}

	public static void kill(int pid) {
		kill((int32)pid);
	}

	public static void suspend(int pid) {
		MWPLog.message(":DBG: suspend for %d\n", pid);
	}

	public static void resume(int pid) {
		MWPLog.message(":DBG: resume for %d\n", pid);
	}
}
