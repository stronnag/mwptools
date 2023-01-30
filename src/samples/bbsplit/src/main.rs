use std::fs::File;
use std::io;
use std::io::{BufRead, BufReader,Write,Seek,Read};
use std::env;
use std::io::SeekFrom;
use std::path::Path;

#[derive(PartialEq)]
enum FState {
    Unknown,
    Opened,
    Writing,
}

#[derive(Debug,Clone)]
struct BBLSegment {
    offset: usize,
    length: usize,
}

fn getmeta(source : &str) -> io::Result<()> {

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
	    let mut buf = vec![0; b.length];
	    f.seek(SeekFrom::Start(b.offset as u64))?;
	    f.read_exact(&mut buf)?;
	    let fname = format!("{:03}-{}",idx+1, Path::new(&source).file_name().unwrap().to_str().unwrap());
	    println!("-> {}", &fname);
	    let mut wh = File::create(fname)?;
	    wh.write_all(&buf)?;
	}
    } else {
	eprintln!("Log {} has no segments", &source);
    }
    Ok(())
}


fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    for a in &args[1..] {
	getmeta(&a)?;
    }
    Ok(())
}
