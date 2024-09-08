## bbsplit - split out multiple logs from a single file

### Usage

When logging to flash (vice SDcard), INAV by default downloads multiple logs into a single file.
This may be mitigated by using MSC mode instead of downloading via [flashgo](https://stronnag.github.io/mwptools/mwp-miscellaneous-tools/#flashgo) or the INAV Configurator, or one can extract the individual logs from the consolidated file using `bbsplit`.

For example:

```
$ bbsplit --help
Usage: bbsplit [options] filename

Options:
    -n, --dry-run       List segments without extraction

```

and

```
$ bbsplit  ~/dl/blackbox_log_2023-01-28_193351.txt
-> 001-blackbox_log_2023-01-28_193351.txt
-> 002-blackbox_log_2023-01-28_193351.txt
-> 003-blackbox_log_2023-01-28_193351.txt
-> 004-blackbox_log_2023-01-28_193351.txt
-> 005-blackbox_log_2023-01-28_193351.txt
```

If the file is not a blackbox log, or only contains a single log, no new file is written.

### Building

Requires `rust`. For convenience there is a Makefile (so you can crib the `Cargo` commands).

* `make release` : Builds release (`target/release/bbsplit`)
* `make debug` : Build debug  (`target/debug/bbsplit`)
* `make install` : Compiles release and installs in `~/.local/bin`
* `make static` : Builds a static (musl) binary. Requires `x86_64-unknown-linux-musl`
* `make static32` : Builds a static 32 bit (musl) binary. Requires `i686-unknown-linux-musl`
* `make windows` : Cross compiles a Windows 64bit binary. Requires `x86_64-pc-windows-gnu`.

If you're building natively on a non-Linux x86_64 platform, then the `release` / `debug` / `install` targets will build native binaries.

### Licence etc.

(c) 2023 Jonathan Hudson. [Zero clause BSD](https://opensource.org/licenses/0BSD)
