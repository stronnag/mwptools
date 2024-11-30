[Flags]
public enum ProcessLaunch {
	NONE = 0,
	STDIN = 1,
	STDOUT = 2,
	STDERR = 4,
	WAIT = 80
}

extern void *create_win_process(char *cmd, int flags, int *spipe, int *epipe, int32 *pid);
extern bool waitproc(void *h, int* sts);
//extern int32 proc_get_pid(void* h);
extern void proc_kill (int32 pid);

public class ProcessLauncher : Object {
	private int spipe;
	private int epipe;
	private int32 pid;
	private int wait_status;
	private bool pstatus;

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


	public bool get_status(int* s) {
		if(s!=null) {
			*s = wait_status;
		}
		return pstatus;
	}

	public bool run_argv(string[]? argv, int flag) {
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
		return run_command(cmd, flag);
	}

	public bool run_command(string cmd, int flag) {
		spipe=-1;
		epipe=-1;
		var res = create_win_process(cmd, flag, &spipe, &epipe, &pid);
		if (res != null) {
			if (ProcessLaunch.WAIT in flag) {
				pstatus = waitproc(res, &wait_status);
			} else {
				new Thread<bool>("wwait", () => {
						pstatus = waitproc(res, &wait_status);
						windone();
						return true;
					});
			}
		}
		return (res != null);
	}

	private void windone() {
		Idle.add(() => {
				complete();
				return false;
			});
	}

	public int get_pid() {
		return (int)pid;
	}

	public static void kill(int pid) {
		proc_kill((int32)pid);
	}

	public static void suspend(int pid) {
		MWPLog.message(":DBG: suspend for %d\n", pid);
	}

	public static void resume(int pid) {
		MWPLog.message(":DBG: resume for %d\n", pid);
	}
}
