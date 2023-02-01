use std::env;
use std::io;

mod crsfreader;
use crate::crsfreader::CRSFReader;

mod mwplogreader;

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 || args[1] == "--help" {
        println!("\nUsage: crsfparser CRSF_file");
        std::process::exit(127);
    } else {
        let mut crsf = CRSFReader::new();
        crsf.init();
        for fname in args[1..].iter() {
            let mut f = mwplogreader::MWPReader::open(fname)?;
            let mut offset = std::option::Option::None;
            loop {
                let mut buf = Vec::new();
                match f.read(&mut buf, &mut offset) {
                    Ok(_) => crsf.parse(buf, offset),
                    Err(_e) => break,
                }
            }
        }
    }
    Ok(())
}
