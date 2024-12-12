/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

namespace Battery {
    private int nsampl = 0;
    private float[] vbsamples;
	private VCol vcol;
	private bool vinit = false;
	public CurrData curr;
	private int icol;
	private int licol;
	private bool update;

	public void init () {
		vcol = new VCol();
		vbsamples = new float[Mwp.MAXVSAMPLE];
		bat_annul();
	}

    private void bat_annul() {
        curr = {false,0,0,0,0 ,0};
        for(var i = 0; i < Mwp.MAXVSAMPLE; i++)
                vbsamples[i] = 0;
        nsampl = 0;
		icol = 4;
    }

	private void init_battery(uint16 ivbat) {
        bat_annul();
        var ncells = ivbat / 37;
        for(var i = 0; i < vcol.levels.length; i++) {
            vcol.levels[i].limit = vcol.levels[i].cell*ncells;
            vcol.levels[i].reached = false;
        }
        vinit = true;
    }

	private void process_msp_analog(MSP_ANALOG2 an) {
        if ((Mwp.replayer & Mwp.Player.MWP) == Mwp.Player.NONE) {
            curr.centiA = an.amps;
            curr.mah = an.mahdraw;
            if(curr.centiA != 0 || curr.mah != 0) {
                curr.ampsok = true;
				Battery.update = true;
                if (curr.centiA > Odo.stats.amps)
                    Odo.stats.amps = curr.centiA;
            }
			if(Logger.is_logging) {
                Logger.analog2(an);
			}
            set_bat_stat(an.vbat);
        }
    }

    private void set_bat_stat(uint16 ivbat) {
		if(ivbat < 20) {
			icol = vcol.levels.length-1;
			if(icol != licol) {
				licol = icol;
			}
			ivbat = 0;
			curr = {false,0,0,0,0 ,0};
			Mwp.msp.td.power.volts = 0.0f;
		} else {
            float  vf = ((float)ivbat)/100.0f;
            if (nsampl == Mwp.MAXVSAMPLE) {
                for(var i = 1; i < Mwp.MAXVSAMPLE; i++)
                    vbsamples[i-1] = vbsamples[i];
            } else {
                nsampl += 1;
			}

            vbsamples[nsampl-1] = vf;
            vf = 0;
            for(var i = 0; i < nsampl; i++) {
                vf += vbsamples[i];
			}
            vf /= nsampl;

            if(vinit == false) {
                init_battery(ivbat/10);  // now centivolts for mwp4
			}
            icol = 0;
            foreach(var v in vcol.levels) {
                if(vf >= v.limit)
                    break;
                icol += 1;
            }

            if (icol > 4)
                icol = 3;

			if (Math.fabs(Mwp.msp.td.power.volts - vf) > 0.1) {
				Battery.update = false;
				Mwp.msp.td.power.volts = vf;
				Mwp.panelbox.update(Panel.View.VOLTS, Voltage.Update.VOLTS);
				if(icol != licol) {
					licol = icol;
				}
				if(vcol.levels[icol].reached == false) {
					vcol.levels[icol].reached = true;
					if(vcol.levels[icol].audio != null) {
						if(Mwp.replayer == Mwp.Player.NONE)
							Audio.play_alarm_sound(vcol.levels[icol].audio);
						else
							MWPLog.message("battery alarm %.1f\n", vf);
					}
				}
            }
			if (Battery.update) {
				Battery.update = false;
				Mwp.panelbox.update(Panel.View.VOLTS, Voltage.Update.CURR);
			}
		}
	}
}