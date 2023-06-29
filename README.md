# HID Report Descriptor Generator (RDG)

rdg.lua is a report descriptor generator (or 'compiler') written in lua,
works with Lua 5.3+ which has bitwise operations built-in.

## Usage

```bash
./rdg.lua [options] <input_file>
lua5.3 ./rdg.lua [options] <input_file>
```

See `./rdg.lua -h` for more details.

For example:

```bash
# convert report descriptor source code file 'keyboard.rds' to binary file 'keyboard.rdb'
./rdg.lua -o ./keyboard.rdb ./keyboard.rds
```

## File Types

### Report Descriptor Source Code (.RDS)

Source code file format.

See [rds.md](./rds.md)

### Report Descriptor Binary (.RDB)

Binary compiled file, which can be directly written to 'report_desc' in configfs.

## Current status

### Functions (Items)

Main Items

- [x] Input()
- [x] Output()
- [x] Feature()
- [x] Collection()
- [x] End_Collection()

Global Items

- [x] Usage_Page()
- [x] Logical*()
- [ ] Physical*()
- [ ] Unit_Exponent()
- [ ] Unit()
- [x] Report_Size()
- [ ] Report_ID()
- [x] Report_Count()
- [ ] Push()
- [ ] Pop()

Local Items

- [x] Usage*()
- [ ] Designator*()
- [ ] String*()
- [ ] Delimiter()

### Usage Pages

- [x] Generic Desktop
- [ ] Simulation Controls
- [ ] VR Controls
- [ ] Sport Controls
- [ ] Game Controls
- [ ] Generic Device Controls
- [x] Keyboard/Keypad
- [x] LED
- [ ] Button
- [ ] Ordinal
- [ ] Telephony Device
- [ ] Consumer
- [ ] Digitizers
- [ ] Haptics
- [ ] Physical Input Device
- [ ] Unicode
- [ ] SoC
- [ ] Eye and Head Trackers
- [ ] Auxiliary Display
- [ ] Sensors
- [ ] Medical Instrument
- [ ] Braille Display
- [ ] Lighting And Illumination
- [ ] Minitor
- [ ] Minitor Enumerated
- [ ] VESA Virtual Controls
- [ ] Power
- [ ] Battery System
- [ ] Barcode Scanner
- [ ] Scales
- [ ] Magnetic Stripe Reader
- [ ] Camera Control
- [ ] Aecade
- [ ] Gaming Device
- [ ] FIDO Alliance


## References

[github.com, HID-PID Descriptor tool](https://github.com/beantowel/HID-descriptor-tool)

[usb.org, Device Class Definition for Human Interface Devices (HID) Firmware Specification](https://www.usb.org/sites/default/files/documents/hid1_11.pdf)

[usb.org, HID Usage Tables FOR Universal Serial Bus (USB)](https://www.usb.org/sites/default/files/hut1_4.pdf)

[gist.github.com, USB HID keycode table + JSON, extracted from HID Usage Tables v1.21](https://gist.github.com/mildsunrise/4e231346e2078f440969cdefb6d4caa3)
