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

// src/main/fc/fc_msp_box.c
// src/main/fc/rc_modes.h

namespace Perm {
	enum ID {
		ARM = 0,
		ANGLE = 1,
		HORIZON = 2,
		NAV_ALTHOLD = 3,
		HEADING_HOLD = 5,
		HEADFREE = 6,
		HEADADJ = 7,
		CAMSTAB = 8,
		NAV_RTH = 10,
		NAV_POSHOLD = 11,
		MANUAL = 12,
		BEEPER = 13,
		LEDS_OFF = 15,
		LIGHTS = 16,
		OSD_OFF = 19,
		TELEMETRY = 20,
		AUTO_TUNE = 21,
		BLACKBOX = 26,
		FAILSAFE = 27,
		NAV_WP = 28,
		AIR_MODE = 29,
		HOME_RESET = 30,
		GCS_NAV = 31,
		FPV_ANGLE_MIX = 32,
		SURFACE = 33,
		FLAPERON = 34,
		TURN_ASSIST = 35,
		NAV_LAUNCH = 36,
		SERVO_AUTOTRIM = 37,
		CAMERA_CONTROL_1 = 39,
		CAMERA_CONTROL_2 = 40,
		CAMERA_CONTROL_3 = 41,
		OSD_ALT_1 = 42,
		OSD_ALT_2 = 43,
		OSD_ALT_3 = 44,
		NAV_COURSE_HOLD = 45,
		MC_BRAKING = 46,
		LOITER_CHANGE = 49,
		MSP_RC_OVERRIDE = 50,
		PREARM = 51,
		TURTLE = 52,
		NAV_CRUISE = 53,
		AUTO_LEVEL_TRIM = 54,
		WP_PLANNER = 55,
		SOARING = 56,
		MISSION_CHANGE = 59,
		BEEPER_MUTE = 60,
		MULTI_FUNCTION = 61,
		MIXER_PROFILE_2 = 62,
		MIXER_TRANSITION = 63,
		ANGLE_HOLD = 64,
		GIMBAL_LEVEL_TILT = 65,
		GIMBAL_LEVEL_ROLL = 66,
		GIMBAL_CENTER = 67,
		GIMBAL_HEADTRACKER = 68
    }
}
