
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

	public void kill(int pid) {
		kill((int32)pid);
	}

	public void suspend(int pid) {
		MWPLog.message(":DBG: suspend for %d\n", pid);
	}

	public void resume(int pid) {
		MWPLog.message(":DBG: resume for %d\n", pid);
	}
}

#if TEST
static int main(string[]? args) {
	if (args.length < 2)
		return 0;

	var p = new ProcessLauncher();
	var m = new MainLoop();
	p.complete.connect(() => {
			Idle.add(() => {
					m.quit();
					return false;
				});
		});

	Idle.add(() => {
			if (p.run(args[1:], 3) == false) {
				print("Failed to run %s\n", args[1]);
				m.quit();
			} else {
				var epipe = p.get_stderr_pipe();
				var spipe = p.get_stdout_pipe();
				if (epipe != -1) {
					IOChannel error = new IOChannel.win32_new_fd(epipe);
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
				if (spipe != -1) {
					IOChannel sout = new IOChannel.win32_new_fd(spipe);
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
			}
			return false;
		});
	m.run();
	return 0;
}
#endif
