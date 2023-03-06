all: release

release:
	cargo build --release

install:
	cargo install --path . --root $$HOME/.local/ --force

static:
	cargo build --target=x86_64-unknown-linux-musl --release

static32:
	cargo build --target i686-unknown-linux-musl --release

debug:
	cargo build

windows:
	cargo build --target x86_64-pc-windows-gnu --release

build: release

clean:
	cargo clean
