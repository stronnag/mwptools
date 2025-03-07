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

public class Locker {
    private string fn;
    private int fd;

    public Locker() {
        StringBuilder sb = new StringBuilder("/tmp/.mwp-");
        sb.append(Environment.get_user_name());
        fn = sb.str;
    }

    public int lock() {
        int res = -1;
        fd = Posix.open(fn, Posix.O_CREAT|Posix.O_WRONLY, 0666);
        if(fd != -1) {
            Posix.Flock f = {Posix.F_WRLCK, Posix.SEEK_SET, 0, 0, 0};
            res = Posix.fcntl(fd, Posix.F_SETLK, &f);
        }
        return res;
    }

    public void unlock() {
        Posix.unlink(fn);
        Posix.close(fd);
    }
}

#if LOCK_TEST_MAIN
public static int main(string[] args) {
    var lck = new Locker();
    var res = lck.lock();
    if(res == 0) {
        Posix.sleep(120);
        lck.unlock();
    }  else {
        print("locked\n");
    }
    return res;
}
#endif
