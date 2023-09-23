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

public class  WPReplicator : Object {
    public static void replicate(Mission ms, uint start, uint end, uint number) {
        MissionItem [] om = ms.get_ways();

        var np = start-1 +(end-start+1)*number+ om.length-end;
        if(start > 0 && end <= om.length && np < 121) {
            MissionItem [] nm = {};
            uint j, k;
            start--; // 0 index
            end--; // 0 index
            for(j = 0; j <= end; j++) // original set of points
                    nm += om[j];

            for(j = 0; j < number; j++) // additional iterations
                for(k = start; k <= end; k++)
                    nm += om[k];

            for(j = end+1; j < om.length; j++) // remaining
                nm += om[j];

            for(j = 0; j < nm.length; j++) // renumber
                nm[j].no = (int)j+1;

            ms.set_ways(nm);
        }
    }
}


#if REPTEST_MAIN

int main (string[] args) {
    Mission ms;
    if ((ms = XmlIO.read_xml_file (args[1])) != null) {
        uint s,e,n;
        s = (uint)int.parse(args[2]);
        e = (uint)int.parse(args[3]);
        n = (uint)int.parse(args[4]);
        WPReplicator.replicate(ms, s, e, n);
        ms.dump();
        XmlIO.to_xml_file("/tmp/rep.mission", ms);
    }
    return 0;
}
