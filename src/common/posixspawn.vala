
public class ProcessLauncher : Object {
	public signal void complete();
	private int spipe;
	private int epipe;
	public int get_stdout_pipe() {
		return spipe;
	}
	public int get_stderr_pipe() {
		return epipe;
	}

	public bool run(string[]? argv, int flags) {
		spipe = -1;
		epipe = -1;
		SpawnFlags spfl = SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD;
		if ((flags & 1) == 0) {
			spfl |= SpawnFlags.STDOUT_TO_DEV_NULL;
		}
		if ((flags & 2) == 0) {
			spfl |= SpawnFlags.STDERR_TO_DEV_NULL;
		}
		try {
			Pid child_pid;
			Process.spawn_async_with_pipes (null,
											argv,
											null,
											spfl,
											null,
											out child_pid,
											null,
											out spipe,
											out epipe);
			ChildWatch.add (child_pid, (pid, status) => {
					Process.close_pid (pid);
					complete();
				});
			return true;
		} catch (Error e) {
			print("%s\n", e.message);
			return false;
		}
	}

	public void kill(int pid) {
		Posix.kill(pid, ProcessSignal.TERM);
	}

	public void suspend(int pid) {
		Posix.kill(pid, ProcessSignal.STOP);
	}

	public void resume(int pid) {
		Posix.kill(pid, ProcessSignal.CONT);
	}
}

#if TEST
static int main(string[]? args) {

	var p = new ProcessLauncher();
	var m = new MainLoop();
	p.complete.connect(() => {
			m.quit();
		});

	Idle.add(() => {
			p.run(args[1:], 3);
			int sp = p.get_stdout_pipe();
			int ep = p.get_stderr_pipe();
			print("run %d %d\n", sp, ep);

			if (ep != -1) {
				IOChannel error = new IOChannel.unix_new(ep);
				error.add_watch (IOCondition.IN|IOCondition.HUP, (s, cond) => {
						try{
							if (cond == IOCondition.HUP) {
								return false;
							}
							string sb;
							size_t slen;
							s.read_to_end(out sb, out slen);
							if (slen > 0) {
								print("E: %s\n", sb);
								return true;
							} else {
								return false;
							}
						} catch {}
						return false;
					});
			}
			if (sp != -1) {
				IOChannel sout = new IOChannel.unix_new(sp);
				sout.add_watch (IOCondition.IN|IOCondition.HUP, (s, cond) => {
						try{
							if (cond == IOCondition.HUP) {
								return false;
							}
							string sb;
							size_t slen;
							s.read_to_end(out sb, out slen);
							if (slen > 0) {
								print("S <%s>\n", sb);
								return true;
							} else {
								return false;
							}
						} catch {}
						return false;
					});
			}
			return false;
		});
	m.run();
	return 0;
}
#endif
