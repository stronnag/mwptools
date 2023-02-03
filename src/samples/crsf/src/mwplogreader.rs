use byteorder::ByteOrder;
use byteorder::LittleEndian;
use std::fs::File;
use std::io;
use std::io::prelude::*;

use std::io::BufReader;
use std::io::SeekFrom;
use std::io::{Error, ErrorKind};

#[cfg(unix)]
use std::os::unix::io::FromRawFd;

extern crate base64;
extern crate json;

#[derive(PartialEq)]
enum Ftype {
    Raw,
    V2,
    Json,
}

pub struct MWPReader {
    ftype: Ftype,
    reader: BufReader<File>,
}
impl MWPReader {

#[cfg(unix)]
    pub fn stdin() -> Result<MWPReader, io::Error> {
	let f = unsafe { File::from_raw_fd(0)};
	let rdr = BufReader::new(f);
	Ok(MWPReader {reader: rdr, ftype: Ftype::Raw,})
    }

#[cfg(not(unix))]
    pub fn stdin() -> Result<MWPReader, io::Error> {
	Err(Error::new(ErrorKind::Other, "platform does not support stdin"))
    }

    pub fn open(fname: &str) -> Result<MWPReader, io::Error> {
	let mut rdr: BufReader<File>;
	let typ: Ftype;
	let f = File::open(fname)?;
        let mut v2 = [0u8; 9];
        rdr = BufReader::new(f);
        rdr.read(&mut v2)?;
        if &v2[0..3] == b"v2\n" {
	    typ = Ftype::V2;
	    rdr.seek(SeekFrom::Start(3))?;
        } else if &v2 == br#"{"stamp":"# {
	    typ = Ftype::Json;
	    rdr.rewind()?;
        } else {
	    rdr.rewind()?;
	    typ = Ftype::Raw;
        }
	Ok(MWPReader {reader: rdr, ftype: typ,})
    }

    pub fn read(&mut self, buf: &mut Vec<u8>, delta: &mut Option<f64>) -> io::Result<()> {
        if self.ftype == Ftype::V2 {
            let mut hdr = vec![0u8; 11];
            self.reader.read_exact(&mut hdr)?;
            let offset = LittleEndian::read_f64(&hdr[0..8]);
            let size = LittleEndian::read_u16(&hdr[8..10]);
            let dirn = hdr[10];
            if dirn == b'o' {
                self.reader.seek(SeekFrom::Current(size as i64))?;
                *delta = None;
                return Ok(());
            }
            *delta = Some(offset);
            *buf = vec![0u8; size.into()];
            self.reader.read_exact(buf)?
        } else if self.ftype == Ftype::Raw {
            *buf = vec![0u8; 512];
            *delta = None;
            let n = self.reader.read(buf)?;
	    if n == 0 {
		return Err(Error::new(ErrorKind::Other, "stdin EOF"));
	    }
        } else {
            let mut s = String::new();
            self.reader.read_line(&mut s)?;
            match json::parse(&s) {
                Ok(parsed) => match parsed["direction"].as_u8() {
                    None => return Err(Error::new(ErrorKind::Other, "JSON EOF")),
                    Some(dirn) => {
                        if dirn == b'i' {
                            match parsed["stamp"].as_f64() {
                                Some(offset) => *delta = Some(offset),
                                None => return Err(Error::new(ErrorKind::Other, "JSON EOF")),
                            }
                            match &parsed["rawdata"].as_str() {
                                Some(v) => *buf = base64::decode(v).unwrap(),
                                None => return Err(Error::new(ErrorKind::Other, "JSON EOF")),
                            }
                        } else {
                            *delta = None;
                            return Ok(());
                        }
                    }
                },
                Err(_) => return Err(Error::new(ErrorKind::Other, "JSON EOF")),
            }
        }
        Ok(())
    }
}
