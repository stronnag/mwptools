/*
 * (some bits) Copyright 2023 Jonathan Hudson
 * Largely based on the Canonical source below
 */

/*
 * Copyright 2013 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *   Charles Kerr <charles.kerr@canonical.com>
 */

public class Device: Object {
  public enum Type {
      OTHER,
      COMPUTER,
      PHONE,
      MODEM,
      NETWORK,
      HEADSET,
      HEADPHONES,
      VIDEO,
      OTHER_AUDIO,
      JOYPAD,
      KEYPAD,
      KEYBOARD,
      TABLET,
      MOUSE,
      PRINTER,
      CAMERA
    }

  public Type device_type { get; construct; }
  public uint id { get; construct; }
  public string name { get; construct; }
  public string address { get; construct; }
  public bool is_connectable { get; construct; }
  public bool is_connected { get; construct; }
  public string print() {
    return @"{id:$id, name:$name, address:$address, device_type:$device_type, is_connectable:$is_connectable, is_connected:$is_connected}";
  }

  public Device (uint id,
                 Type device_type,
                 string name,
                 string address,
				 bool is_connectable,
                 bool is_connected)
  {
    Object (id: id,
            device_type: device_type,
            name: name,
            address: address,
            is_connectable: is_connectable,
            is_connected: is_connected);
  }

  public static Type class_to_device_type (uint32 c) {
    switch ((c & 0x1f00) >> 8) {
        case 0x01:
          return Type.COMPUTER;

        case 0x02:
          switch ((c & 0xfc) >> 2) {
              case 0x01:
              case 0x02:
              case 0x03:
              case 0x05:
                return Type.PHONE;

              case 0x04:
                return Type.MODEM;
            }
          break;

        case 0x03:
          return Type.NETWORK;

        case 0x04:
          switch ((c & 0xfc) >> 2) {
              case 0x01:
              case 0x02:
                return Type.HEADSET;

              case 0x06:
                return Type.HEADPHONES;

              case 0x0b: // vcr
              case 0x0c: // video camera
              case 0x0d: // camcorder
                return Type.VIDEO;

              default:
                return Type.OTHER_AUDIO;
            }

        case 0x05:
          switch ((c & 0xc0) >> 6) {
              case 0x00:
                switch ((c & 0x1e) >> 2) {
                    case 0x01:
                    case 0x02:
                      return Type.JOYPAD;
                  }
                break;

              case 0x01:
                return Type.KEYBOARD;

              case 0x02:
                switch ((c & 0x1e) >> 2)
                  {
                    case 0x05:
                      return Type.TABLET;

                    default:
                      return Type.MOUSE;
                  }
            }
          break;

        case 0x06:
          if ((c & 0x80) != 0)
            return Type.PRINTER;
          if ((c & 0x20) != 0)
            return Type.CAMERA;
          break;
      }
    return 0;
  }
}
