# Report Descriptor Source Code (.RDS)

## Basic Code Format

### Comments

```
# Starts with either `#` or `;`

# This is a comment
; This is another comment

```

### Constants, Values

Currently there's no way to define a variable or function, so all of available
constants and functions are built-in.

Some constants are only available with specific arguments, like
`Usage(Keyboard)` is actually only valid after the closest
`Usage_Page(Generic_Desktop)`. Also, `Generic_Desktop` may only be used for
function `Usage_Page()`

Many functions' arguments can be either *names* or *numbers*.

- For a valid *name*, each char could be a letter, number or underline.
	Starting with number is not a valid *name*.
- For a valid *number*, either a signed integer or a signed hex value(starts with `0x`) is supported.

Examples:

```
g3n3r1c_DESKtop
84
-0x3
```

All of them are case-insensitive, like `Usage()` and `uSAGE()` do the same
function.

### Functions (Items)

```
# Syntax
# args may be: string(without quotes) /numberic value, splitted with comma.
<function_name>(args...)

# Examples
Usage_Page(Generic_Desktop)
# `Variable` is 0x2
Input(Data, 0x2, Relative)

```

### Code Structure

- Each function ends with a *newline*
- Each line represents a command with more than one byte in binary.
- Indents are ignored in compilation; they are only for readability.

## Examples

### Keyboard Example From [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/usb/gadget_hid.html)

With some modifications to let it work.

```
Usage_Page(Generic_Desktop)
Usage(Keyboard)
Collection(Application)
	usage_page(keyboard)
	usage_minimum(keyboard_leftcontrol)
	usage_maximum(keyboard_right_gui)
	logical_minimum(0)
	logical_maximum(1)
	report_size(1)
	report_count(8)
	input(data, variable, absolute)
	report_count(1)
	report_size(8)
	input(constant, variable, absolute)
	report_count(5)
	report_size(1)
	usage_page(led)
	usage_minimum(num_lock)
	usage_maximum(kana)
	output(data, variable, absolute)
	report_count(1)
	report_size(3)
	output(constant, variable, absolute)
	report_count(6)
	report_size(8)
	logical_minimum(0)
	logical_maximum(101)
	usage_page(keyboard)
	usage_minimum(reserved)
	usage_maximum(keyboard_application)
	input(data, array, absolute)
End_Collection()
```

### Mouse Example

```
Usage_Page(Generic_Desktop)
Usage(Mouse)
Collection(Application)
	Usage(Pointer)
	Collection(Physical)
		Usage_Page(Button)
		Usage_Minimum(1)
		Usage_Maximum(3)
		Logical_Minimum(0)
		Logical_Maximum(1)
		Report_Count(3)
		Report_Size(5)
		Input(Constant)
		Usage_Page(Generic_Desktop)
		Usage(X)
		Usage(Y)
		Logical_Minimum(-127)
		Logical_Maximum(-127)
		Report_Size(8)
		Report_Count(2)
		Input(Data, Variable, Relative)
	End_Collection()
End_Collection()
```

## References

[HID-PID Descriptor tool](https://github.com/beantowel/HID-descriptor-tool)

[Device Class Definition for Human Interface Devices (HID) Firmware Specification](https://www.usb.org/sites/default/files/documents/hid1_11.pdf)

[HID Usage Tables FOR Universal Serial Bus (USB)](https://www.usb.org/sites/default/files/hut1_4.pdf)
