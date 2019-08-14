/***
fn nm2r(nm: f64) -> f64 {
    (std::f64::consts::PI/(180.0*60.0))*nm
}
***/
fn r2nm(r: f64) -> f64 {
    ((180.0*60.0)/std::f64::consts::PI)*r
}

pub fn csedist(_lat1: f64, _lon1: f64, _lat2: f64, _lon2: f64) -> (f64,f64) {
    let lat1 = _lat1.to_radians();
    let lon1 = _lon1.to_radians();
    let lat2 = _lat2.to_radians();
    let lon2 = _lon2.to_radians();
    let dlat = lat1-lat2;
    let dlon = lon1-lon2;

    let p1 = (dlat/2.0).sin();
    let p2 = lat1.cos()*lat2.cos();
    let p3 = (dlon/2.0).sin();

    let d0 = 2.0*((p1*p1)+p2*(p3*p3)).sqrt().asin();
    let d = r2nm(d0);
    let y = dlon.sin() * lat2.cos();
    let x = lat1.cos()*lat2.sin()-lat1.sin()*lat2.cos()*dlon.cos();

    let cse =  y.atan2(x) % (2.0*std::f64::consts::PI);
    let c = cse.to_degrees();
    (c,d)
}

/***
pub fn posit(lat1: f64, lon1: f64, cse: f64, dist:f64, rhumb: bool) -> (f64,f64) {
    let tc = cse.to_radians();
    let rlat1 = lat1.to_radians();
    let rdist = nm2r(dist);
    let lat: f64;
    let dlon: f64;

    if rhumb == true {
        lat= rlat1+rdist*tc.cos();
        let mut tmp = (lat/2.0 + std::f64::consts::PI/4.0).tan() /
            (rlat1/2.0 + std::f64::consts::PI/4.0).tan();
        if tmp <= 0.0 {
            tmp = 0.000000001;
        }
        let dphi=tmp.ln();
        let q = if dphi == 0.0 || (lat-rlat1).abs() < 1.0e-6 {
            rlat1.cos()
        } else {
            (lat-rlat1)/dphi
        };
        dlon = rdist*tc.sin()/q;
    } else {
        lat = (rlat1.sin()*rdist.cos() +
               rlat1.cos() * rdist.sin() * tc.cos()).asin();
        let y = tc.sin() * rdist.sin() * rlat1.cos();
        let x = rdist.cos() - rlat1.sin() * lat.sin();
        dlon = y.atan2(x);
    }
    let lon = ((std::f64::consts::PI + lon1.to_radians() + dlon) % (2.0 * std::f64::consts::PI)) - std::f64::consts::PI;
    (lat.to_degrees(),lon.to_degrees())
}
***/
