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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace SEDE {
	public uint8* deserialise_u64(uint8* rp, out uint64 v) {
		uint32 u;
		rp = deserialise_u32(rp, out u);
		v = u;
		rp = deserialise_u32(rp, out u);
		v = v | ((uint64)u << 32);
		return rp;
	}

	public uint8* deserialise_u32(uint8* rp, out uint32 v) {
		v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
		return rp + sizeof(uint32);
	}

	public uint8* deserialise_i32(uint8* rp, out int32 v) {
		v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
		return rp + sizeof(int32);
	}

	public uint8* deserialise_u16(uint8* rp, out uint16 v) {
		v = *rp | (*(rp+1) << 8);
		return rp + sizeof(uint16);
	}

	public uint8* deserialise_i16(uint8* rp, out int16 v) {
		v = *rp | (*(rp+1) << 8);
		return rp + sizeof(int16);
	}

	public uint8 * serialise_u16(uint8* rp, uint16 v) {
		*rp++ = v & 0xff;
		*rp++ = v >> 8;
		return rp;
	}

	public uint8 * serialise_i16(uint8* rp, int16 v) {
		return serialise_u16(rp, (int16)v);
	}

	public uint8 * serialise_u32(uint8* rp, uint32 v) {
		*rp++ = v & 0xff;
		*rp++ = ((v >> 8) & 0xff);
		*rp++ = ((v >> 16) & 0xff);
		*rp++ = ((v >> 24) & 0xff);
		return rp;
	}

	public uint8 * serialise_i32(uint8* rp, int32 v) {
		return serialise_u32(rp, (int32)v);
	}

}
