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

#include <windows.h>

static unsigned int mPrevScreenSaver;

void uninhibit(unsigned int cookie) {
  SystemParametersInfo(SPI_SETSCREENSAVETIMEOUT, mPrevScreenSaver, NULL, 0);
  SetThreadExecutionState(cookie);
}

unsigned int inhibit(void) {
  unsigned int cookie = SetThreadExecutionState(ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED | ES_CONTINUOUS);
  SystemParametersInfo(SPI_GETSCREENSAVETIMEOUT, 0, &mPrevScreenSaver, 0);
  SystemParametersInfo(SPI_SETSCREENSAVETIMEOUT, FALSE, NULL, 0);
  return cookie;
}
