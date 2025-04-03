using SDL;



int main() {
	int njoy = SDL.init (SDL.InitFlag.JOYSTICK);
	if (njoy < 0) {
		print("Unable to initialize the joystick subsystem.\n");
        return 127;
    }
	njoy = SDL.Input.Joystick.count();
	print("There are %d joysticks connected.\n", njoy);

	SDL.Input.Joystick js;

	if (njoy > 0) {
		js = new SDL.Input.Joystick(0);
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
			print("Axis %d value %d.\n", event.jaxis.axis, event.jaxis.value);
			break;
		case SDL.EventType.JOYHATMOTION:
			print("Hat %d value %d.\n", event.jhat.hat, event.jhat.value);
			break;
		case SDL.EventType.JOYBUTTONDOWN:
			print("Button %d pressed.\n", event.jbutton.button);
			break;
		case SDL.EventType.JOYBUTTONUP:
			print("Button %d released.\n", event.jbutton.button);
			break;
		case SDL.EventType.JOYDEVICEADDED:
			print("Joystick %d connected\n", event.jdevice.which);
			break;
		case SDL.EventType.JOYDEVICEREMOVED:
			print("Joystick %d removed.\n", event.jdevice.which);
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