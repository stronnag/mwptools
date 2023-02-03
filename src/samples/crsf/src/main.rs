use std::env;
use std::io;

mod crsfreader;
use crate::crsfreader::CRSFReader;

mod mwplogreader;

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() == 2 && args[1] == "--help" {
        println!("\nUsage: crsfparser CRSF_file|stdin");
    } else {
	let input = env::args().nth(1);
	let mut f = match input {
	    None => mwplogreader::MWPReader::stdin()?,
	    Some(fname) => mwplogreader::MWPReader::open(&fname)?
	};
        let mut crsf = CRSFReader::new();
        crsf.init();
	let mut offset = std::option::Option::None;
        loop {
            let mut buf = Vec::new();
            match f.read(&mut buf, &mut offset) {
                Ok(_) => crsf.parse(buf, offset),
                Err(_e) => break,
            }
        }
    }
    Ok(())
}
