use byteorder::LittleEndian;
use byteorder::ReadBytesExt;
use std::fs::File;
use std::io;
use std::io::prelude::*;

use std::io::BufReader;
use std::io::SeekFrom;

pub struct MWPReader {
    ftype: u8,
    reader: BufReader<File>,
}
impl MWPReader {
    pub fn open(fname: &str) -> Result<MWPReader, io::Error> {
        let f = File::open(fname)?;
        let mut v2 = [0; 3];
        let mut reader = BufReader::new(f);
        reader.read(&mut v2)?;
        let typ: u8;
        if v2 == [118, 50, 10] {
            typ = 0;
        } else {
            reader.rewind()?;
            typ = 1;
        }
        Ok(MWPReader {
            reader: reader,
            ftype: typ,
        })
    }

    pub fn read(&mut self, buf: &mut Vec<u8>, delta: &mut Option<f64>) -> io::Result<()> {
        if self.ftype == 0 {
            let offset = self.reader.read_f64::<LittleEndian>()?;
            let size = self.reader.read_u16::<LittleEndian>()?;
            let dirn = self.reader.read_u8()?;
            if dirn == b'o' {
                self.reader.seek(SeekFrom::Current(size as i64))?;
                *delta = None;
                return Ok(());
            }
            *delta = Some(offset);
            *buf = vec![0u8; size.into()];
            self.reader.read_exact(buf)?
        } else {
            *buf = vec![0u8; 128];
            *delta = None;
            self.reader.read_exact(buf)?
        }
        Ok(())
    }
}
