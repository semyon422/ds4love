local ffi = require("ffi")
local crc32 = require("crc32")

local dsu = {}

local sources = {
	client = "DSUC",
	server = "DSUS"
}

local message_types = {
	version = 0x100000,
	ports = 0x100001,
	data = 0x100002
}

local pad_states = {
	disconnected = 0x00,
	reserved = 0x01,
	connected = 0x02
}

local connection_types = {
	none = 0x00,
	usb = 0x01,
	bluetooth = 0x02
}

local models = {
	none = 0x00,
	partial_gyro = 0x01,
	full_gyro = 0x02,
	generic = 0x03
}

local battery_statuses = {
	none = 0x00,
	dying = 0x01,
	low = 0x02,
	medium = 0x03,
	high = 0x04,
	full = 0x05,
	charging = 0xee,
	charged = 0xff
}

local register_flags = {
	all_pads = 0x00,
	pad_id = 0x01,
	pad_mac_address = 0x02
}

dsu.sources = sources
dsu.message_types = message_types
dsu.pad_states = pad_states
dsu.connection_types = connection_types
dsu.models = models
dsu.battery_statuses = battery_statuses
dsu.register_flags = register_flags

dsu.decode = function(b)
	local header = dsu.decode_header(b)

	local source = ffi.string(header.source, 4)
	local message_type = header.message_type

	if source == sources.client then
		if message_type == message_types.version then
			dsu.decode_version_request(b)
		elseif message_type == message_types.ports then
			dsu.decode_list_ports(b)
		elseif message_type == message_types.data then
			dsu.decode_pad_data_request(b)
		end
	elseif source == sources.server then
		if message_type == message_types.version then
			dsu.decode_version_response(b)
		elseif message_type == message_types.ports then
			dsu.decode_port_info(b)
		elseif message_type == message_types.data then
			dsu.decode_pad_data_response(b)
		end
	end
end

dsu.encode = function(b)
	local header = dsu.header

	local source = ffi.string(header.source, 4)
	local message_type = header.message_type

	local data
	if source == sources.client then
		if message_type == message_types.version then
			data = dsu.encode_version_request()
		elseif message_type == message_types.ports then
			data = dsu.encode_list_ports()
		elseif message_type == message_types.data then
			data = dsu.encode_pad_data_request()
		end
	elseif source == sources.server then
		if message_type == message_types.version then
			data = dsu.encode_version_response()
		elseif message_type == message_types.ports then
			data = dsu.encode_port_info()
		elseif message_type == message_types.data then
			data = dsu.encode_pad_data_response()
		end
	end

	header.crc32 = 0
	header.protocol_version = 1001
	header.message_length = #data + 4
	local packet_string = ffi.string(header, 20) .. data

	header.crc32 = crc32.hash(packet_string)

	packet_string = ffi.string(header, 20) .. data

	return packet_string
end

ffi.cdef([[
	typedef struct {
		uint8_t source[4];
		uint16_t protocol_version;
		uint16_t message_length;
		uint32_t crc32;
		uint32_t source_uid;
		uint32_t message_type;
	} dsu_header_t;
]])
local dsu_header = ffi.new("dsu_header_t")
dsu.header = dsu_header
dsu.decode_header = function(b)
	ffi.copy(dsu_header, b:string(20))
	return dsu_header
end
dsu.encode_header = function()
	return ffi.string(dsu_header, 20)
end

ffi.cdef([[
	typedef struct {
		uint8_t pad_id;
		uint8_t pad_state;
		uint8_t model;
		uint8_t connection_type;
		uint8_t pad_mac_address[6];
		uint8_t battery_status;
	} dsu_shared_response_t;
]])
local dsu_shared_response = ffi.new("dsu_shared_response_t")
dsu.shared_response = dsu_shared_response
dsu.decode_shared_response = function(b)
	ffi.copy(dsu_shared_response, b:string(11))
	return dsu_shared_response
end
dsu.encode_shared_response = function()
	return ffi.string(dsu_shared_response, 11)
end

ffi.cdef([[
	typedef struct {
		uint8_t active;
		uint8_t id;
		uint16_t x;
		uint16_t y;
	} dsu_touch_t;
]])
local dsu_touch = ffi.new("dsu_touch_t")
dsu.touch = dsu_touch
dsu.decode_touch = function(b)
	ffi.copy(dsu_touch, b:string(6))
	return dsu_touch
end
dsu.encode_touch = function()
	return ffi.string(dsu_touch, 6)
end

dsu.decode_version_request = function()
	return {}
end
dsu.encode_version_request = function()
	return ""
end

ffi.cdef([[
	typedef struct {
		int32_t pad_request_count;
		uint8_t pad_id[4];
	} dsu_list_ports_t;
]])
local dsu_list_ports = ffi.new("dsu_list_ports_t")
dsu.list_ports = dsu_list_ports
dsu.decode_list_ports = function(b)
	ffi.copy(dsu_list_ports, b:string(8))
	return dsu_list_ports
end
dsu.encode_list_ports = function()
	return ffi.string(dsu_list_ports, 8)
end

ffi.cdef([[
	typedef struct {
		uint8_t register_flags;
		uint8_t pad_id_to_register;
		uint8_t mac_address_to_register[6];
	} dsu_pad_data_request_t;
]])
local dsu_pad_data_request = ffi.new("dsu_pad_data_request_t")
dsu.pad_data_request = dsu_pad_data_request
dsu.decode_pad_data_request = function(b)
	ffi.copy(dsu_pad_data_request, b:string(8))
	return dsu_pad_data_request
end
dsu.encode_pad_data_request = function()
	return ffi.string(dsu_pad_data_request, 8)
end

ffi.cdef([[
	typedef struct {
		uint16_t max_protocol_version;
		uint8_t padding[2];
	} dsu_version_response_t;
]])
local dsu_version_response = ffi.new("dsu_version_response_t")
dsu.version_response = dsu_version_response
dsu.decode_version_response = function(b)
	ffi.copy(dsu_version_response, b:string(4))
	return dsu_version_response
end
dsu.encode_version_response = function()
	return ffi.string(dsu_version_response, 4)
end

dsu.decode_port_info = function(b)
	return dsu.decode_shared_response(b)
end
dsu.encode_port_info = function()
	return dsu.encode_shared_response() .. "\0"
end

ffi.cdef([[
	typedef struct {
		dsu_shared_response_t dsu_shared_response;
		uint8_t active;
		uint32_t hid_packet_counter;
		uint8_t button_states1;
		uint8_t button_states2;
		uint8_t button_ps;
		uint8_t button_touch;
		uint8_t left_stick_x;
		uint8_t left_stick_y_inverted;
		uint8_t right_stick_x;
		uint8_t right_stick_y_inverted;
		uint8_t button_dpad_left_analog;
		uint8_t button_dpad_down_analog;
		uint8_t button_dpad_right_analog;
		uint8_t button_dpad_up_analog;
		uint8_t button_square_analog;
		uint8_t button_cross_analog;
		uint8_t button_circle_analog;
		uint8_t button_triangle_analog;
		uint8_t button_r1_analog;
		uint8_t button_l1_analog;
		uint8_t trigger_r2;
		uint8_t trigger_l2;
		dsu_touch_t dsu_touch1;
		dsu_touch_t dsu_touch2;
		uint64_t timestamp_us;
		float accelerometer_x_g;
		float accelerometer_y_g;
		float accelerometer_z_g;
		float gyro_pitch_deg_s;
		float gyro_yaw_deg_s;
		float gyro_roll_deg_s;
	} dsu_pad_data_response_t;
]])
local dsu_pad_data_response = ffi.new("dsu_pad_data_response_t")
dsu.pad_data_response = dsu_pad_data_response
dsu.decode_pad_data_response = function(b)
	ffi.copy(dsu_pad_data_response, b:string(80))
	return dsu_pad_data_response
end
dsu.encode_pad_data_response = function()
	return ffi.string(dsu_pad_data_response, 80)
end

return dsu
