#!/usr/bin/env lua

--[[
	A HID Report Descriptor Generator written in Lua
	===
	works with Lua 5.3+
	---

	MIT License

	Copyright (c) 2023 JulianDroid

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

local os = require 'os'


--[[
	Utils
	Some constants, variables or functions depend on them
]]

-- binary
local B = {
	__pow = function(self, num) return tonumber(tostring(num), 2) end
}
setmetatable(B, B)

-- logger
local function log(msg)
	io.stderr:write('==> ' .. msg .. '\n')
	io.stderr:flush()
end

-- enum
local __enum_skip_magic = {}
local __enum_start_magic = {}
local __enum_repeat_magic = {}
local function __enum_repeat(k) return {__magic = __enum_repeat_magic, k = k} end
local function __enum_skip(n) return {__magic = __enum_skip_magic, n = n or 1} end
local function __enum_start(i) return {__magic = __enum_start_magic, i = assert(i)} end
local function enum(items, start_index)
	local index = start_index or 0
	local res = {}
	for i=1, #items do
		local item = items[i]
		if type(item) == 'table' then
			if item.__magic == __enum_repeat_magic then
				res[item.k], index = index, index + 1
			elseif item.__magic == __enum_skip_magic then
				-- skip
				index = index + item.n
			elseif item.__magic == __enum_start_magic then
				if item.i <= index then error('start index must be bigger than previous') end
				index = item.i
			else error('invalid item in enum') end
		else
			res[item] = index
			index = index + 1
		end
	end
	return res
end


--[[
	Constants and Variables
]]

local help_string = [[
rdg.lua - a hid report descriptor generator
Usage: rdg.lua [OPTIONS] <input_file>

Possible OPTIONS:
  -o, --output=FILE          write data to FILE; '-' to write to stdout
                               default: <input_file>.rdb

Arguments:
  input_file                 read source code from input_file, suffix may be
                               '.rds'

File suffix:
  .rds                       Report Descriptor Source Code
  .rdb                       Report Descriptor Compiled Binary

]]

--[[
	References:
		https://github.com/beantowel/HID-descriptor-tool/blob/master/HID_PID_Definitions.py
		https://www.usb.org/sites/default/files/documents/hid1_11.pdf
		https://www.usb.org/sites/default/files/hut1_4.pdf
		https://gist.github.com/mildsunrise/4e231346e2078f440969cdefb6d4caa3
]]

--[[
	Report Descriptor Item
	[...bits] = byte
	* = any

	Short item:
		[ **** ** ** ]
		| ---- -- -- |
		|  ^^  ^^ ^^ |
		|  ||  || || |
		|  ||  || ++-|-- size
		|  ||  ++----|-- type
		|  ++--------|-- tag
		+------------+

	Long item:
		[ 1111 11 10 ] [ ******** ] [ ******** ]
		| ---------- | | -------- | | -------- |
		|    FIXED   | |   size   | |    tag   |
		+------------+ +----------+ +----------+
]]

local __rditem_type_map = {
	main = 0,
	global = 1,
	['local'] = 2,
	reserved = 4
}
local __rditem_log2_map = {
	[0] = 0,
	[1] = 1,
	[2] = 2,
	[4] = 3
}
local __rditem_obj_base = {
	bytes = nil,
	type = nil,
	is_long = false,
	-- to save memory, we do not generate a new object
	update_size = function(self, _size)
		size = __rditem_log2_map[_size]
		assert(size, 'size must be 0, 1, 2 or 4')
		if self.is_long then
			-- TODO
			error('impl')
		else
			local b = self.bytes[1]
			b = (b & B^11111100) | size
			self.bytes[1] = b
		end

		return self
	end,
	__metatable = false
}
setmetatable(__rditem_obj_base, __rditem_obj_base)
local function __rditem(size, tag, type, is_long)
	local _type = (type or 'main'):lower()
	-- size would be overrided in actual situation
	size = assert(__rditem_log2_map[size], 'invalid size') & B^11
	type = assert(__rditem_type_map[_type]) & B^11
	tag = assert(tag) & B^1111

	local obj = {
		bytes = {},
		type = _type,
		is_long = is_long,
		__index = __rditem_obj_base
	}
	setmetatable(obj, obj)

	-- TODO
	if is_long then error('impl')
	else
		obj.bytes[1] = size | (type << 2) | (tag << 4)
	end

	return obj
end

local rd_compiler_item_map = (function()
	-- v = tag
	local config = {
		main = {
			input = B^1000,
			output = B^1001,
			feature = B^1011,
			collection = B^1010,
			end_collection = B^1100,
		},
		global = {
			usage_page = B^0000,
			logical_minimum = B^0001,
			logical_maximum = B^0010,
			physical_minimum = B^0011,
			physical_maximum = B^0100,
			unit_exponent = B^0101,
			unit = B^0110,
			report_size = B^0111,
			report_id = B^1000,
			report_count = B^1001,
			report_push = B^1010,
			report_pop = B^1011,
		},
		['local'] = {
			usage = B^0000,
			usage_minimum = B^0001,
			usage_maximum = B^0010,
			designator_index = B^0011,
			designator_minimum = B^0100,
			designator_maximum = B^0101,
			string_index = B^0111,
			string_minimum = B^1000,
			string_maximum = B^1001,
			delimiter = B^1010,
		},
	}

	local map = {}
	for type, table in pairs(config) do
		for item_name, tag in pairs(table) do
			map[item_name] = __rditem(0, tag, type)
		end
	end

	return map
end)()

-- starts with _ means a ctx is required
local rd_compiler_argument_map = {
	usage_page = enum {
		__enum_start(0x01),
		'generic_desktop',
		'simulation',
		'vr',
		'sport_controls',
		'game',
		'generic_device',
		'keyboard',
		'led',
		'button',
		'ordinal',
		'telephony_device',
		'consumer',
		'digitizers',
		'haptics',
		'physical_input_device',
		'reserved'
	},
	_usage = {
		-- classified by usage_page
		generic_desktop = enum {
			__enum_start(0x01),
			'pointer',
			'mouse',
			__enum_skip(1),
			'joystick',
			'gamepad',
			'keyboard',
			'keypad',
			'multiaxis_controller',
			'tablet_pc_system_controls',
			'water_cooling_device',
			'computer_chassis_device',
			'wireless_radio_controls',
			'portable_device_control',
			'system_multiaxis_controller',
			'spatial_controller',
			'assistive_control',
			'device_dock',
			'dockable_device',
			'call_state_management_control',
			__enum_start(0x30),
			'x',
			'y',
			'z',
			-- TODO to be continued
		},
		--[[
			partially from (bash)
			grep Keypad |sed -E -e 's/ =.*//g' -e "s/ and.*//g" -e "s/(.*)/'\\1',/g" |tr '[:upper:]' '[:lower:]' |tr ' ' '_'
		]]
		keyboard = enum {
			'reserved',
			'keyboard_errorrollover',
			'keyboard_postfail',
			'keyboard_errorundefined',
			'keyboard_a',
			'keyboard_b',
			'keyboard_c',
			'keyboard_d',
			'keyboard_e',
			'keyboard_f',
			'keyboard_g',
			'keyboard_h',
			'keyboard_i',
			'keyboard_j',
			'keyboard_k',
			'keyboard_l',
			'keyboard_m',
			'keyboard_n',
			'keyboard_o',
			'keyboard_p',
			'keyboard_q',
			'keyboard_r',
			'keyboard_s',
			'keyboard_t',
			'keyboard_u',
			'keyboard_v',
			'keyboard_w',
			'keyboard_x',
			'keyboard_y',
			'keyboard_z',
			'keyboard_1',
			'keyboard_2',
			'keyboard_3',
			'keyboard_4',
			'keyboard_5',
			'keyboard_6',
			'keyboard_7',
			'keyboard_8',
			'keyboard_9',
			'keyboard_0',
			'keyboard_return',
			__enum_repeat('keyboard_enter'),
			'keyboard_escape',
			'keyboard_delete',
			__enum_repeat('keyboard_backspace'),
			'keyboard_tab',
			'keyboard_spacebar',
			'keyboard_minus',
			'keyboard_equal',
			'keyboard_leftbracket',
			'keyboard_rightbracket',
			'keyboard_backslash',
			'keyboard_non-us_hash',
			'keyboard_semicolon',
			'keyboard_quote',
			'keyboard_grave_accent',
			'keyboard_comma',
			'keyboard_dot',
			'keyboard_slash',
			'keyboard_caps_lock',
			'keyboard_f1',
			'keyboard_f2',
			'keyboard_f3',
			'keyboard_f4',
			'keyboard_f5',
			'keyboard_f6',
			'keyboard_f7',
			'keyboard_f8',
			'keyboard_f9',
			'keyboard_f10',
			'keyboard_f11',
			'keyboard_f12',
			'keyboard_printscreen',
			'keyboard_scroll_lock',
			'keyboard_pause',
			'keyboard_insert',
			'keyboard_home',
			'keyboard_pageup',
			'keyboard_delete_forward',
			'keyboard_end',
			'keyboard_pagedown',
			'keyboard_rightarrow',
			'keyboard_leftarrow',
			'keyboard_downarrow',
			'keyboard_uparrow',
			'keypad_num_lock',
			'keypad_div',
			'keypad_multiply',
			'keypad_minus',
			'keypad_plus',
			'keypad_enter',
			'keypad_1',
			'keypad_2',
			'keypad_3',
			'keypad_4',
			'keypad_5',
			'keypad_6',
			'keypad_7',
			'keypad_8',
			'keypad_9',
			'keypad_0',
			'keypad_dot',
			'keyboard_non-us_backslash',
			'keyboard_application',
			'keyboard_power',
			'keypad_equal',
			'keyboard_f13',
			'keyboard_f14',
			'keyboard_f15',
			'keyboard_f16',
			'keyboard_f17',
			'keyboard_f18',
			'keyboard_f19',
			'keyboard_f20',
			'keyboard_f21',
			'keyboard_f22',
			'keyboard_f23',
			'keyboard_f24',
			'keyboard_execute',
			'keyboard_help',
			'keyboard_menu',
			'keyboard_select',
			'keyboard_stop',
			'keyboard_again',
			'keyboard_undo',
			'keyboard_cut',
			'keyboard_copy',
			'keyboard_paste',
			'keyboard_find',
			'keyboard_mute',
			'keyboard_volume_up',
			'keyboard_volume_down',
			'keyboard_locking_caps_lock',
			'keyboard_locking_num_lock',
			'keyboard_locking_scroll_lock',
			'keypad_comma',
			'keypad_equal_sign',
			'keyboard_international1',
			'keyboard_international2',
			'keyboard_international3',
			'keyboard_international5',
			'keyboard_international5',
			'keyboard_international6',
			'keyboard_international7',
			'keyboard_international8',
			'keyboard_international9',
			'keyboard_lang1',
			'keyboard_lang2',
			'keyboard_lang3',
			'keyboard_lang4',
			'keyboard_lang5',
			'keyboard_lang6',
			'keyboard_lang7',
			'keyboard_lang8',
			'keyboard_lang9',
			'keyboard_alternate_erase',
			'keyboard_sysreq',
			'keyboard_cancel',
			'keyboard_clear',
			'keyboard_prior',
			'keyboard_return',
			'keyboard_separator',
			'keyboard_out',
			'keyboard_oper',
			'keyboard_clear',
			'keyboard_crsel',
			'keyboard_exsel',
			__enum_start(0xb0),
			'keypad_00',
			'keypad_000',
			'thousands_separator',
			'decimal_separator',
			'currency_unit',
			'currency_subunit',
			'keypad_leftparenthesis',
			'keypad_rightparenthesis',
			'keypad_leftbrace',
			'keypad_rightbrace',
			'keypad_tab',
			'keypad_backspace',
			'keypad_a',
			'keypad_b',
			'keypad_c',
			'keypad_d',
			'keypad_e',
			'keypad_f',
			'keypad_xor',
			'keypad_caret',
			'keypad_percent',
			'keypad_lessthan',
			'keypad_greaterthan',
			'keypad_ampersand',
			'keypad_double_ampersand',
			'keypad_pipe',
			'keypad_double_pipe',
			'keypad_colon',
			'keypad_hash',
			'keypad_space',
			'keypad_at',
			'keypad_exclamation',
			'keypad_memory_store',
			'keypad_memory_recall',
			'keypad_memory_clear',
			'keypad_memory_add',
			'keypad_memory_subtract',
			'keypad_memory_multiply',
			'keypad_memory_divide',
			'keypad_plus',
			'keypad_minus',
			'keypad_clear',
			'keypad_clear_entry',
			'keypad_binary',
			'keypad_octal',
			'keypad_decimal',
			'keypad_hexadecimal',
			__enum_start(0xe0),
			'keyboard_leftcontrol',
			'keyboard_leftshift',
			'keyboard_leftalt',
			'keyboard_left_gui',
			'keyboard_rightcontrol',
			'keyboard_rightshift',
			'keyboard_rightalt',
			'keyboard_right_gui',
		},
		led = enum {
			__enum_start(1),
			'num_lock',
			'caps_lock',
			'scroll_lock',
			'compose',
			'kana',
			'power',
			'shift',
			'do_not_disturb',
			'mute',
			'tone_enable',
			'high_cut_filter',
			'low_cut_filter',
			'equalizer_enable',
			'sound_field_on',
			'surround_on',
			'repeat',
			'stereo',
			'sampling rate detect',
			'spinning',
			'cav',
			'clv',
			'recording_format_detect',
			'off_hook',
			'ring',
			'message_waiting',
			'data_mode',
			'battery_operation',
			'battery_ok',
			'battery_low',
			'speaker',
			'headset',
			'hold',
			'microphone',
			'coverage',
			'night_mode',
			'send_calls',
			'call_pickup',
			'conference',
			'stand_by',
			'camera_on',
			'camera_off',
			'on_line',
			'off_line',
			'busy',
			'ready',
			'paper_out',
			'paper_jann',
			'remote',
			'forward',
			'reverse',
			'stop',
			'rewind',
			'fast_forward',
			'play',
			'pause',
			'record',
			'error',
			'usage_selected_indicator',
			'usage_in_use_indicator',
			'usage_multi_mode_indicator',
			'indicator_on',
			'indicator_flash',
			'indicator_slow_blink',
			'indicator_fast_blink',
			'indicator_off',
			'flash_on_time',
			'slow_blink_on_time',
			'slow_blink_off_time',
			'fast_blink_on_time',
			'fast_blink_off_time',
			'usage_indicator_color',
			'indicator_red',
			'indicator_green',
			'indicator_amber',
			'generic_indicator',
			'system_suspend',
			'external_power_connected',
			'indicator_blue',
			'indicator_orange',
			'good_status',
			'warning_status',
			'rgb_led',
			'red_led_channel',
			'blue_led_channel',
			'green_led_channel',
			'led_intensity',
			'system_microphone_mute',
			'reserved',
			__enum_start(0x60),
			'player_indicator',
			'player_1',
			'player_2',
			'player_3',
			'player_4',
			'player_5',
			'player_6',
			'player_7',
			'player_8'
			-- reserved
		},
		button = enum {
			
		}
	},
	collection = enum {
		'physical',
		'application',
		'logical',
		'report',
		'named_array',
		'usage_switch',
		'usage_modifier',
		'reserved'
	},
	iof = {
		data = 0,
		constant = B^1,
		array = 0,
		variable = B^10,
		absolute = 0,
		relative = B^100,
		no_wrap = 0,
		wrap = B^1000,
		linear = 0,
		nonlinear = B^10000,
		preferred_state = 0,
		no_preferred = B^100000,
		no_null_position = 0,
		null_state = B^1000000,
		non_volatile = 0,
		volatile = B^10000000,
		bit_field = 0,
		buffered_bytes = B^100000000,
		reserved = (1<<9)
	}
}

-- parse value
local function rd_compiler_pv(table, key, bits)
	-- bits = (assert(bits, 'negative value without bits length'))
	bits = bits or 8
	if key:match('^%-*0x([0-9a-fA-F]+)$') or key:match('^%-*[0-9]+$') then
		local num = tonumber(key)
		if num < 0 then
			num = (-num) | (1 << bits - 1)
		end
		return num
	else return table[key] end
end

local rd_compiler = {
	usage_page = function(ctx, name)
		local b = rd_compiler_argument_map.usage_page[name]
		if not b then return end
		return {b}, nil, name
	end,
	-- with usage_minimum, usage_maximum
	usage = function(ctx, name)
		local gn = ctx.g.usage_page
		if gn == 'keypad' then gn = 'keyboard' end
		if not gn then return nil, 'missing correct usage_page() before usage*()' end
		local context = rd_compiler_argument_map._usage[gn]
		if not context then return nil, 'undefined usage for "' .. gn .. '"' end
		local b = rd_compiler_pv(context, name)
		if not b then return end
		return {b}
	end,
	__logical = function(ctx, num)
		local b = rd_compiler_pv(nil, num)
		if not b then return nil, 'invalid numberic value in function logical*()' end
		return {b}
	end,
	report_size = function(ctx, num)
		local b = tonumber(num)
		if not b then return nil, 'invalid numberic value in function report_size()' end
		return {b}
	end,
	report_count = function(ctx, num)
		local b = tonumber(num)
		if not b then return nil, 'invalid numberic value in function report_count()' end
		return {b}
	end,
	-- input, output, feature
	__iof = function(ctx, ...)
		local args = {...}
		local b = 0

		for i=1, #args do
			local name = args[i]:lower()
			local c = rd_compiler_argument_map.iof[name]
			if c == nil then return end
			b = b | c
		end

		return {b}
	end,
	collection = function(ctx, name)
		local b = rd_compiler_argument_map.collection[name]
		if not b then return end
		return {b}, nil, true, name
	end,
	end_collection = function()
		return {}, nil, false
	end
}
rd_compiler.usage_minimum = rd_compiler.usage
rd_compiler.usage_maximum = rd_compiler.usage
rd_compiler.logical_minimum = rd_compiler.__logical
rd_compiler.logical_maximum = rd_compiler.__logical
rd_compiler.input = rd_compiler.__iof
rd_compiler.output = rd_compiler.__iof
rd_compiler.feature = rd_compiler.__iof


--[[
	Functions
]]

local function show_help()
	print(help_string)
end

local function optassert(prev, opt)
	if not opt then
		log('Expected one argument after option "' .. prev .. '"')
		show_help()
		os.exit(1)
	end
	return opt
end

local function parse_rds(input)
	local data = {}
	local line = input:read('l')
	-- local vars
	local context = {
		-- all of them are command-specific
		--[[
			local
			properties will be pushed or popped
		]]
		l = {},
		--[[
			Global context
			all properties will only be altered
		]]
		g = {}
	}
	-- debug
	local line_number = 0
	while line do
		line_number = line_number + 1
		-- parse line
		local comment = line:match('^%s*[#;]')
		local blank = line:match('^%s*$')
		if not comment and not blank then
			local func_name, func_args_str = line:match('([%w_]+)%s*%((.*)%)')
			func_name = func_name:lower()
			local compiler = rd_compiler[func_name]
			if compiler then
				-- parse args and trim them
				local args = {}
				for arg in func_args_str:gmatch('([^,]+)') do
					args[#args + 1] = arg:match('^%s*(%-*[%w_]-)%s*$'):lower()
				end
				local chunk, err, new_status, field_value = compiler(context, table.unpack(args))
				--[[
					new_status:
						$string: push status into context
						false: set nil or pop current status
				]]
				if chunk then
					local item = rd_compiler_item_map[func_name]
					data[#data + 1] = string.char(item:update_size(#chunk).bytes[1])
					for i=1, #chunk do data[#data + 1] = string.char(chunk[i]) end chunk = nil
					if new_status ~= nil then
						if item.type == 'global' then
							-- alter
							context.g[func_name] = new_status == false and nil or new_status
						else
							-- push or pop
							if new_status == false then
								context.l[#context.l], context.l.curr = nil, context.l[#context.l - 1]
							else
								local n = {}
								context.l[#context.l + 1], context.l.curr = n, n
							end
						end
					end
					if item.type ~= 'global' and field_value then
						context.l.curr[func_name] = field_value
					end
					-- -- push context
					-- if new_context_name and not context_mode then
						-- context[#context + 1] = new_context_name
					-- -- pop, alter context
					-- elseif context_mode then
						-- if context_mode == 'pop' then context[#context] = nil
						-- elseif context_mode == 'alter' then context[#context] = new_context_name end
					-- end
				else
					log('in line ' .. line_number .. ':')
					log(line)
					return nil, err or 'invalid argument in function "' .. func_name .. '"'
				end
			else
				return nil, 'unexpected function "' .. func_name .. '" at line ' .. line_number
			end
		end
		-- next
		line = input:read('l')
	end

	if #context.l ~= 0 then
		-- TODO
		-- log('context stack:')
		-- log('global:')
		-- for k, #context.g do log('    ' .. context.g)
		return nil, 'extra context stack detected'
	end

	return table.concat(data)
end


--[[
	Main
]]

local function main(args)
	local input_file = nil
	local output_file = nil

	-- parse args
	do local i = 1 while i <= #args do
		local opt = args[i]
		if opt == '-h' or opt == '--help' then show_help() return 0
		elseif opt == '-o' or opt == '--output' then output_file = optassert(opt, args[i+1])
		else
			if opt:sub(1, 1) == '-' then
				log('Unrecognized option "' .. opt .. '"')
				show_help()
				return 1
			end

			if not input_file then
				input_file = opt
			else
				log('Unrecognized extra argument "' .. opt .. '"')
				show_help()
				return 1
			end
			i = i - 1
		end
		i = i + 2
	end end

	if not input_file then
		log('Too few arguments')
		show_help()
		return 1
	end

	output_file = output_file or input_file .. '.rdb'

	-- parse file
	local content, parse_err = nil, nil
	if input_file == '-' then
		content, parse_err = parse_rds(io.stdin)
	else
		local input = assert(io.open(input_file))
		content, parse_err = parse_rds(input)
		input:close()
	end

	if not content then
		log('Error: ' .. (parse_err or 'invalid argument in source code'))
		return 2
	end

	local output = nil
	if output_file == '-' then
		io.stdout:write(content)
		io.stdout:flush()
	else
		local output = io.open(output_file, 'w+')
		if not output then
			log('Error: cannot open output file "' .. output_file .. '"')
			return 2
		end
		output:write(content)
		output:flush()
		output:close()
	end

	log('Success')
end

local ret = main(arg)
if ret and ret ~= 0 then os.exit(ret) end
