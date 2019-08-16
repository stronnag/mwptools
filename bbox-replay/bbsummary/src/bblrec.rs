extern crate csv;
extern crate regex;
extern crate json;

use std::collections::HashMap;
use csv::Trim;
use std::process::{Command, Stdio};
use std::io::{Error,ErrorKind};

use std::path::PathBuf;
use std::fs;
use std::env;

use regex::Regex;

mod poscalc;

type Record = HashMap<String, String>;

struct BBLRec {
    lat: f64,
    lon: f64,
    alt: f64,
    spd: f64,
    amps: Option<f64>,
    fix: Option<u8>,
    numsat: u8,
}

fn get_record(r: Record) -> BBLRec {
    let mut amps = None;
    let mut fix = None;
    let mut alt = 0.0;

    match r.get("amperage (A)") {
        Some(x) => { amps = Some(x.parse::<f64>().unwrap()) },
        _ => {
            match r.get("currentVirtual (A)") {
                Some(x) => { amps = Some(x.parse::<f64>().unwrap()) },
                _ => (),
            }
        },
    };

    match r.get("BaroAlt (cm)") {
        Some(x) => { alt = x.parse::<f64>().unwrap() },
        _ => { match r.get("GPS Altitude") {
            Some(x) => { alt = x.parse::<f64>().unwrap() },
            _ => (),
        }
        },
    };

    match r.get("GPS_fixType") {
        Some(x) => { fix = Some(x.parse::<u8>().unwrap()) },
        _ => (),
    };

    let g = BBLRec{
        lat: r["GPS_coord[0]"].parse::<f64>().unwrap(),
        lon: r["GPS_coord[1]"].parse::<f64>().unwrap(),
        spd: r["GPS_speed (m/s)"].parse::<f64>().unwrap(),
        fix: fix,
        alt: alt,
        amps: amps,
        numsat:  r["GPS_numSat"].parse::<u8>().unwrap(),
    };
    return g;
}

const CURRENT :usize = 0;
const ALTITUDE :usize = 1;
const SPEED :usize = 2;
const RANGE :usize = 3;
const DISTANCE :usize = 4;

struct Summary {
    name: &'static str,
    unit: &'static str,
    value: f64,
    elapsed: u32,
}

fn show_time(t: u32) -> String {
    let secs  = t / 1000000;
    let m = secs / 60;
    let s = secs % 60;
    format!("{:02}:{:02}", m, s)
}

fn get_vehicle_args(vname: &str) -> Option<String> {
    let home = env::var("HOME").unwrap();
    let mut rstr: Option<String> = None;
    let jfile: PathBuf = [home, ".config/mwp/replay_ltm.json".to_string() ].iter().collect();
    if jfile.exists() {
        let s = fs::read_to_string(jfile).unwrap();
        let parsed = json::parse(&s).unwrap();
        for (k,v) in parsed["extra"].entries() {
            let re = Regex::new(k).unwrap();
            if re.is_match(vname) {
                rstr = Some(v.to_string());
                break;
            }
        }
    }
    rstr
}

pub fn log_summary(fname: &str, idx: u8, dumph: bool, vname: &str) -> Result<(), Error> {

    let mut summary: [Summary;5] = [
        Summary {name: "Current", unit: "A", value: 0.0, elapsed: 0},
        Summary {name: "Altitude", unit: "m",  value: -99999.0, elapsed: 0},
        Summary {name: "Speed", unit: "m/s", value: 0.0, elapsed: 0},
        Summary {name: "Range", unit: "m", value: 0.0, elapsed: 0},
        Summary {name: "Distance", unit: "m", value: 0.0, elapsed: 0},
    ];

    let mut st = 0;
    let mut lt = 0;
    let istr = idx.to_string();

    let mut vargs: Vec<&str> = ["--merge-gps", "--stdout", "--index", istr.as_str()].to_vec();

    let mut _ss = "".to_string();
    if let Some(s) =  get_vehicle_args(&vname) {
        _ss = s.to_string();
        let mut split: Vec<&str> = _ss.split(' ').collect();
        vargs.append(&mut split);
    }
    vargs.push(fname);

    let child = Command::new("blackbox_decode")
        .args(&vargs)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()?;

    let output = child.stdout
        .ok_or_else(|| Error::new(ErrorKind::Other,
                                  "Could not capture standard output."))?;

    let mut rdr = csv::ReaderBuilder::new()
        .trim(Trim::All)
        .from_reader(output);

    let headers = rdr.headers()?;
    if dumph == true {
        println!("{:?}", headers);
    } else {
        let mut have_origin = false;
        let mut have_baro = false;
        let mut is_valid = false;
        let mut olat = 0.0;
        let mut olon = 0.0;
        let mut oalt = 0.0;
        let mut llat = 0.0;
        let mut llon = 0.0;

        for field in headers.iter() {
            if field == "GPS_fixType" || field == "GPS_numSat" {
                is_valid = true;
            }
            if field == "BaroAlt (cm)" {
                have_baro = true;
            }
        }

        if is_valid {
            for result in rdr.deserialize() {
                let record: Record = result?;
                let us = record["time (us)"].parse::<u32>().unwrap();
                let g = get_record(record);

                if have_origin == false {
                    let mut satok = false;

                    match g.fix {
                        Some(x) => {if x == 2 { satok = true;}},
                        _ => {if g.numsat > 5 { satok = true;}},
                    }

                    if satok {
                        have_origin = true;
                        olat = g.lat;
                        olon = g.lon;
                        oalt = g.alt;
                        llat = g.lat;
                        llon = g.lon;
                        st = us;
                    }
                }

                match g.amps {
                    Some(x) => {
                        if x > summary[CURRENT].value {
                            summary[CURRENT].value = x;
                            summary[CURRENT].elapsed = us - st;
                        }
                    },
                    _ => (),
                }

                if g.alt > summary[ALTITUDE].value {
                    summary[ALTITUDE].value = g.alt;
                    summary[ALTITUDE].elapsed = us - st;
                }

                if g.spd > summary[SPEED].value {
                    summary[SPEED].value = g.spd;
                    summary[SPEED].elapsed = us - st;
                }

                if have_origin == true {
                    let (_c,d) = poscalc::csedist(olat, olon, g.lat, g.lon);
                    if d > summary[RANGE].value {
                        summary[RANGE].value = d;
                        summary[RANGE].elapsed = us - st;
                    }

                    if llat != g.lat && llon != g.lon {
                        let (_c,d) = poscalc::csedist(llat, llon, g.lat, g.lon);
                        summary[DISTANCE].value += d;
                        llat = g.lat;
                        llon = g.lon;
                    }
                    lt = us;
                }
            }

            if have_origin  {
                if have_baro {
                    summary[ALTITUDE].value /= 100.0;
                } else {
                    summary[ALTITUDE].value -= oalt;
                }
                summary[RANGE].value *= 1852.0;
                summary[DISTANCE].value *= 1852.0;

                let et: u32 = lt - st;

                for s in &summary {
                    print!("{:9}: {:.1} {}", s.name, s.value, s.unit);
                    if s.elapsed > 0 {
                        println!(" at {}", show_time(s.elapsed));
                    } else {
                        println!();
                    }
                }
                println!("{:9}: {}", "Duration", show_time(et));
            } else {
                println!("failed to process log/index");
            }
        } else {
            println!("* No GPS information in log");
        }
    }
    Ok(())
}
