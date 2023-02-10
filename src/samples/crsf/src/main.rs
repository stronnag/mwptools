extern crate getopts;

use getopts::Options;
use std::env;
use std::io;

mod crsfreader;
use crate::crsfreader::CRSFReader;

mod mwplogreader;

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn print_usage(program: &str, opts: &Options) {
    let brief = format!("Usage: {} [options] [file]\nVersion: {}", program, VERSION);
    print!("{}", opts.usage(&brief));
}

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let program = args[0].clone();
    let mut rftype: u8 = 0;

    let mut opts = Options::new();
    opts.optopt("r", "rfmode-type", "RFMode interpretation", "[0,2,3]");
    opts.optflag("h", "help", "print this help menu");

    let matches = match opts.parse(&args[1..]) {
        Ok(m) => m,
        Err(f) => {
            panic!("{}", f.to_string())
        }
    };

    if matches.opt_present("h") {
        print_usage(&program, &opts);
        return Ok(());
    }

    if let Ok(Some(px)) = matches.opt_get::<u8>("r") {
        rftype = px
    }

    let mut f = if !matches.free.is_empty() {
        mwplogreader::MWPReader::open(&matches.free[0])?
    } else {
        mwplogreader::MWPReader::stdin()?
    };
    let mut crsf = CRSFReader::new(rftype);
    let mut offset = std::option::Option::None;
    loop {
        let mut buf = Vec::new();
        match f.read(&mut buf, &mut offset) {
            Ok(_) => crsf.parse(buf, offset),
            Err(_e) => break,
        }
    }
    Ok(())
}
