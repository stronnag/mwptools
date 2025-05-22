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

using SDL;

static int deadband = 0;

const OptionEntry[] options = {
	{"deadband", 'd', 0, OptionArg.INT, ref deadband, "Deadband (in SDL frame of reference)", null},
	{null}
};

int main(string?[]args) {
	bool []gcs = new bool[16];
	int []last = new int[16];

	try {
		var opt = new OptionContext("");
		opt.set_help_enabled(true);
		opt.add_main_entries(options, null);
		opt.parse(ref args);
	}
	catch (OptionError e) {
		stderr.printf("Error: %s\n", e.message);
		stderr.printf("Run '%s --help' to see a full list of available options\n", args[0]);
		return 1;
	}

	int njoy = SDL.init (SDL.InitFlag.JOYSTICK|SDL.InitFlag.GAMECONTROLLER);
	if (njoy < 0) {
		print("Unable to initialize the joystick subsystem.\n");
        return 127;
    }
	njoy = SDL.Input.Joystick.count();
	print("There are %d joysticks connected.\n", njoy);

	for(int i=0; i < njoy; i++) {
		var guid = SDL.Input.Joystick.get_guid_from_device(i);
		var gstr = SDL.Input.Joystick.get_guid_string(guid);
		gcs[i] = SDL.Input.GameController.is_game_controller(i);
		print("Entry %d, %s guid=%s game controller=%s\n", i, SDL.Input.Joystick.get_name_for_index(i),gstr,  gcs[i].to_string());
	}

	print("Deadband: %d\n", deadband);

	SDL.Input.Joystick js;
	int jid = 0;
	if (njoy > 0) {
		if(njoy > 1) {
			print("Enter controller ID: ");
			string? jstr = stdin.read_line ();
			if(jstr == null) {
				return 1;
			}
			var id = int.parse(jstr);
			if (id < 0 || id >= njoy) {
				return 2;
			}
			jid = id;
		}

		js = new SDL.Input.Joystick(jid);
		if(gcs[jid] && args.length > 1) {
			SDL.Input.GameController.load_mapping_file(args[1]);
		}
		if (js == null) {
            print("There was an error opening joystick 0.\n");
            return 127;
        } else {
			print("Name: %s\n", js.get_name());
			print("No. axes %d\n", js.num_axes());
			print("No. balls %d\n", js.num_balls());
			print("No. buttons %d\n", js.num_buttons());
			print("No. hats %d\n", js.num_hats());
		}
    } else {
        print("There are no joysticks connected. Exiting...\n");
        return 127;
    }

    SDL.Event event;

	while (SDL.Event.wait (out event) == 1) {
		if (event.type == SDL.EventType.QUIT)
			break;
		switch(event.type) {
		case SDL.EventType.JOYAXISMOTION:
			if(deadband == 0) {
				print("Joy Axis %d value %d.\n", event.jaxis.axis, event.jaxis.value);
			} else {
				var ilast = last[event.jaxis.axis];
				if((event.jaxis.value-ilast).abs() > deadband) {
					print("Joy Axis %d value %d.\n", event.jaxis.axis, event.jaxis.value);
					last[event.jaxis.axis] = event.jaxis.value;
				}
			}
			break;
		case SDL.EventType.JOYHATMOTION:
			print("Joy Hat %d value %d.\n", event.jhat.hat, event.jhat.value);
			break;
		case SDL.EventType.JOYBUTTONDOWN:
			print("Joy Button %d pressed.\n", event.jbutton.button);
			break;
		case SDL.EventType.JOYBUTTONUP:
			print("Joy Button %d released.\n", event.jbutton.button);
			break;
		case SDL.EventType.JOYDEVICEADDED:
			print("Joystick %d connected\n", event.jdevice.which);
			break;
		case SDL.EventType.JOYDEVICEREMOVED:
			print("Joystick %d removed.\n", event.jdevice.which);
			break;
		case SDL.EventType.CONTROLLERAXISMOTION:
			print("Controller Axis %d value %d.\n", event.caxis.axis, event.caxis.value);
			break;
		case SDL.EventType.CONTROLLERBUTTONDOWN:
			print("Controller Button %d pressed.\n", event.cbutton.button);
			break;
		case SDL.EventType.CONTROLLERBUTTONUP:
			print("Controller Button %d released.\n", event.cbutton.button);
			break;
		case SDL.EventType.CONTROLLERDEVICEADDED:
			print("Controller %d connected\n", event.cdevice.which);
			break;
		case SDL.EventType.CONTROLLERDEVICEREMOVED:
			print("Controller %d removed.\n", event.cdevice.which);
			break;
		case SDL.EventType.CONTROLLERDEVICEREMAPPED:
			print("Controller %d remapped.\n", event.cdevice.which);
			break;
		case 607:
			//	print("Joystick %d battery update\n", event.jdevice.which);
			break;
		case 608:
			//print("Joystick %d update complete\n", event.jdevice.which);
			break;
		default:
			print("Unhandled %d %x\n", event.type, event.type);
			break;
		}
	}
    SDL.quit ();
	return 0;
}