/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[Flags]
public enum ProcessLaunch {
	NONE = 0,
	STDIN = 1,
	STDOUT = 2,
	STDERR = 4,
	WAIT = 8,
	WINSPECIAL= 10
}

extern void *create_win_process(char *cmd, int flags, int *ipipe, int *spipe, int *epipe, int32 *pid);
extern bool waitproc(void *h, int* sts);
extern void proc_kill (int32 pid);
extern void winsuspend (int32 pid);
extern void winresume (int32 pid);
extern int pid_from_name(char *procname);

public class ProcessLauncher : Object {
	private int spipe;
	private int ipipe;
	private int epipe;
	private int32 pid;
	private int wait_status;
	private bool pstatus;

	public int get_stdin_pipe() {
		return ipipe;
	}
	public int get_stdout_pipe() {
		return spipe;
	}
	public int get_stderr_pipe() {
		return epipe;
	}

	public IOChannel get_stdin_iochan() {
		return new IOChannel.win32_new_fd(ipipe);
	}

	public IOChannel get_stdout_iochan() {
		return new IOChannel.win32_new_fd(spipe);
	}

	public IOChannel get_stderr_iochan() {
		return new IOChannel.win32_new_fd(epipe);
	}

	public signal void complete();

	public bool get_status(out int? s) {
		s = wait_status;
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
		var res = create_win_process(cmd, flag, &ipipe, &spipe, &epipe, &pid);
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
		winsuspend(pid);
	}

	public static void resume(int pid) {
		MWPLog.message(":DBG: resume for %d\n", pid);
		winresume(pid);
	}

	public static int find_pid_from_name(string name) {
		string pname;
		if(name.has_suffix(".exe")) {
			pname = name;
		} else {
			pname = name + ".exe";
		}
		return pid_from_name(pname);
	}
}
