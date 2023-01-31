use std::fmt;
use std::fs::File;
use std::io;
use std::io::{BufRead, BufReader,Write,Seek,Read};
use std::env;
use std::io::SeekFrom;
use std::path::Path;
use getopts::Options;

#[derive(PartialEq)]
enum FState {
    Unknown,
    Opened,
    Writing,
}

#[derive(Clone,Debug)]
struct BBLSegment {
    offset: usize,
    length: usize,
}

impl fmt::Display for BBLSegment {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
	write!(f,"offset: {:8}, length: {:8}", self.offset, self.length)
    }
}

fn getmeta(source : &str, save: bool) -> io::Result<()> {
    let hbbox: &[u8] = b"H Product:Blackbox flight data recorder by Nicholas Sherlock\n";
    let hbblen = hbbox.len();
    let f = File::open(source)?;
    let mut buf = vec![];
    let mut f = BufReader::new(f);
    let mut fstate = FState::Unknown;
    let mut asize = 0;
    let mut bbls: Vec<BBLSegment> = Vec::new();
    let mut seg = BBLSegment{length:0, offset:0};

    while let Ok(size) = f.read_until(0x0a as u8, &mut buf) {
        if size == 0 {
	    break;
	}
	asize += size;
	let hdiff = size as i64 - hbblen as i64;
	if hdiff >= 0 {
	    if &buf[hdiff as usize..] == hbbox {
		if fstate != FState::Unknown {
		    seg.length += hdiff as usize;
		    bbls.push(seg.clone());
		}
		fstate = FState::Opened;
		seg.offset = asize - hbblen;
	    }
	}
	match fstate {
	    FState::Opened => {
		fstate = FState::Writing;
		seg.length = hbblen;
	    },
	    FState::Writing => {
		seg.length += size;
	    },
	    _ => (),
	}
	buf.clear();
    }
    bbls.push(seg.clone());

    if bbls.len() > 1 {
        for (idx, b) in bbls.iter().enumerate() {
	    let fname = format!("{:03}-{}",idx+1, Path::new(&source).file_name().unwrap().to_str().unwrap());
	    println!("-> {} {}", &fname, b);
	    if save {
		let mut buf = vec![0; b.length];
		f.seek(SeekFrom::Start(b.offset as u64))?;
		f.read_exact(&mut buf)?;
		let mut wh = File::create(fname)?;
		wh.write_all(&buf)?;
	    }
	}
    } else {
	eprintln!("Log {} has no segments", &source);
    }
    Ok(())
}

fn print_usage(program: &str, opts: &Options) {
    let brief = format!("Usage: {} [options] filename(s)", program);
    print!("{}", opts.usage(&brief));
}

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let program = args[0].clone();
    let mut opts = Options::new();

    opts.optflag("n", "dry-run", "List segments without extraction");

    let matches = match opts.parse(&args[1..]) {
        Ok(m) => m,
        Err(_) => {
            print_usage(&program, &opts);
            std::process::exit(1);
        }
    };

    if matches.free.is_empty() {
	print_usage(&program, &opts);
        std::process::exit(1);
    }

    for a in matches.free.clone() {
	getmeta(&a, !matches.opt_present("n"))?;
   }
    Ok(())
}
