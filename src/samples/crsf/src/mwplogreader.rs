use byteorder::ByteOrder;
use byteorder::LittleEndian;
use std::fs::File;
use std::io;
use std::io::prelude::*;

use std::io::BufReader;
use std::io::SeekFrom;
use std::io::{Error, ErrorKind};

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
    pub fn open(fname: &str) -> Result<MWPReader, io::Error> {
        let f = File::open(fname)?;
        let mut v2 = [0; 3];
        let mut reader = BufReader::new(f);
        reader.read(&mut v2)?;
        let typ: Ftype;
        if v2 == [118, 50, 10] {
            typ = Ftype::V2;
        } else if v2 == [b'{', b'"', b's'] {
            typ = Ftype::Json;
            reader.rewind()?;
        } else {
            reader.rewind()?;
            typ = Ftype::Raw;
        }
        Ok(MWPReader {
            reader: reader,
            ftype: typ,
        })
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
            *buf = vec![0u8; 128];
            *delta = None;
            self.reader.read_exact(buf)?
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
