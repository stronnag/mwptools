[Flags]
public enum ProcessLaunch {
	NONE = 0,
	STDIN = 1,
	STDOUT = 2,
	STDERR = 4,
	WAIT = 8,
	WINSPECIAL= 10
}

extern int  parse_wstatus(int stst, int* wsts);
extern int pid_from_name(char *name);

public class ProcessLauncher : Object {
	public signal void complete();
	private int ipipe;
	private int spipe;
	private int epipe;
	private Pid child_pid;
	private int wait_status;

	public bool get_status(out int? sts) {
		int _sts = -1;
		var res = parse_wstatus(wait_status, &_sts);
		sts = _sts;
		return (bool) res;
	}

	public int get_stdin_pipe() {
		return ipipe;
	}
	public int get_stdout_pipe() {
		return spipe;
	}
	public int get_stderr_pipe() {
		return epipe;
	}

	public IOChannel get_stdout_iochan() {
		return new IOChannel.unix_new(spipe);
	}

	public IOChannel get_stdin_iochan() {
		return new IOChannel.unix_new(ipipe);
	}

	public IOChannel get_stderr_iochan() {
		return new IOChannel.unix_new(epipe);
	}

	public bool run_command(string cmd, int flags) {
		string []exa;
		try {
			Shell.parse_argv(cmd, out exa);
			return run_argv(exa, flags);
		} catch {}
		return false;
	}

	public bool run_argv(string[]? argv, int flags) {
		spipe = -1;
		epipe = -1;
		ipipe = -1;

		SpawnFlags spfl = SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD;
		if (!(ProcessLaunch.STDOUT in flags)) {
			spfl |= SpawnFlags.STDOUT_TO_DEV_NULL;
		}
		if (!(ProcessLaunch.STDERR in flags)) {
			spfl |= SpawnFlags.STDERR_TO_DEV_NULL;
		}
		try {
			Process.spawn_async_with_pipes (null,
											argv,
											null,
											spfl,
											null,
											out child_pid,
											out ipipe,
											out spipe,
											out epipe);
			if(ProcessLaunch.WAIT in flags) {
				Posix.waitpid(child_pid, out wait_status, 0);
			} else {
				ChildWatch.add (child_pid, (pid, status) => {
						Process.close_pid (pid);
						wait_status = status;
						complete();
				});
			}
			return true;
		} catch (Error e) {
			print("%s\n", e.message);
			return false;
		}
	}

	public int get_pid() {
		return child_pid;
	}

	public static void kill(int pid) {
		Posix.kill(pid, ProcessSignal.TERM);
	}

	public static void suspend(int pid) {
		Posix.kill(pid, ProcessSignal.STOP);
	}

	public static void resume(int pid) {
		Posix.kill(pid, ProcessSignal.CONT);
	}

	public static int find_pid_from_name(string name) {
		return pid_from_name(name);
	}
}
