extern crate regex;
use regex::Regex;

use std::fs::File;
use std::io::{BufRead, BufReader, Result};


pub struct Bblmeta {
    pub l: Vec<Loginfo>,
}

pub struct Loginfo {
    pub git: String,
    pub gdate: String,
    pub name: String,
    pub ldate: String,
    pub disarm: String,
}

const DISARMED: [&'static str; 8] = ["NONE", "TIMEOUT", "STICKS", "SWITCH_3D", "SWITCH", "KILL SWITCH", "FAILSAFE", "NAVIGATION"];

impl Bblmeta {
    pub fn new() -> Bblmeta {
        Bblmeta { l:  Vec::new() }
    }

    pub fn getmeta(&mut self, source : &str) -> Result<()> {
        let file = File::open(source)?;
        let rg = Regex::new(r"H ([A-Za-z_ 0-9]*):(.*)").unwrap();
        let mut buf = vec![];
        let mut reader = BufReader::new(file);

        while let Ok(_) = reader.read_until(0x0a as u8, &mut buf) {
            if buf.len() == 0 { break}
            let lstr = String::from_utf8_lossy(&buf);
            match rg.captures(&lstr) {
                Some(x) => {
                    match x.get(1).unwrap().as_str() {
                        "Data version" => {
                            self.l.push(Loginfo {git: String::new(),
                                                 gdate: String::new(),
                                                 name: String::new(),
                                                 ldate: String::new(),
                                                 disarm: "NONE".to_string()});
                        },
                        "Firmware date" => if let Some(l) = self.l.last_mut() {
                            l.gdate = x.get(2).unwrap().as_str().to_string();
                        },
                        "Firmware revision" => if let Some(l) = self.l.last_mut() {
                            l.git = x.get(2).unwrap().as_str().to_string();
                        },
                        "Craft name" => if let Some(l) = self.l.last_mut() {
                            l.name = x.get(2).unwrap().as_str().to_string();
                        },
                        "Log start datetime" => if let Some(l) = self.l.last_mut() {
                            l.ldate = x.get(2).unwrap().as_str().to_string();
                        },
                        _ => (),
                    }
                }
                None => ()
            }
            match lstr.find("End of log (disarm reason:") {
                Some(x) => {
                    let rtxt = &lstr[x+26..x+27];
                    let reason = rtxt.parse::<u8>().unwrap();
                    if let Some(l) = self.l.last_mut() {
                        l.disarm =DISARMED[reason as usize].to_string();
                    }
                },
                None => ()
            }
            buf.truncate(0);
        }
        Ok(())
    }
}
