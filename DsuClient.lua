local ffi = require("ffi")
local dsu = require("dsu")
local socket = require("socket")
local byte = require("byte")

local DsuClient = {}

DsuClient.new = function(self)
	local dsuClient = {}

	dsuClient.portInfo = {}
	dsuClient.padData = {}
	dsuClient.updateCounter = 0

	setmetatable(dsuClient, self)
	self.__index = self

	return dsuClient
end

DsuClient.versionRequestCallback = function(self, version) end
DsuClient.listPortsCallback = function(self, info) end
DsuClient.padDataRequestCallback = function(self, data) end

DsuClient.connect = function(self, host, port)
	local udp = assert(socket.udp())
	self.udp = udp
	udp:settimeout(0)
	assert(udp:setpeername(host, port))
end

DsuClient.versionRequest = function(self)
	dsu.header.source = "DSUC"
	dsu.header.source_uid = 1
	dsu.header.message_type = dsu.message_types.version
	assert(self.udp:send(dsu.encode()))
end

DsuClient.listPorts = function(self)
	dsu.header.source = "DSUC"
	dsu.header.source_uid = 1
	dsu.header.message_type = dsu.message_types.ports
	dsu.list_ports.pad_request_count = 4
	dsu.list_ports.pad_id = {0, 1, 2, 3}
	local message = dsu.encode()
	assert(self.udp:send(message))
end

DsuClient.padDataRequest = function(self)
	dsu.header.source = "DSUC"
	dsu.header.source_uid = 1
	dsu.header.message_type = dsu.message_types.data
	dsu.pad_data_request = dsu.register_flags.all_pads
	assert(self.udp:send(dsu.encode()))
end

local buffer = byte.buffer(100)
DsuClient.update = function(self, dt)
	local udp = self.udp
	local response = udp:receive()
	while response do
		buffer:seek(0):fill(response):seek(0)
		dsu.decode(buffer)

		local source = ffi.string(dsu.header.source, 4)
		local message_type = dsu.header.message_type

		if source == dsu.sources.server then
			if message_type == dsu.message_types.version then
				self:handleVersionResponse()
			elseif message_type == dsu.message_types.ports then
				self:handlePortInfo()
			elseif message_type == dsu.message_types.data then
				self:handlePadDataResponse()
			end
		end
		response = udp:receive()
	end
	self.updateCounter = self.updateCounter + dt
	if self.updateCounter > 1 then
		self.updateCounter = self.updateCounter - 1
		self:padDataRequest()
	end
end

DsuClient.handleVersionResponse = function(self)
	return self:versionRequestCallback(dsu.version_response.max_protocol_version)
end

DsuClient.handlePortInfo = function(self)
	local response = dsu.shared_response
	local portInfo = self.portInfo

	portInfo[response.pad_id + 1] = portInfo[response.pad_id + 1] or {}

	local info = portInfo[response.pad_id + 1]
	info.pad_id = response.pad_id
	info.pad_state = response.pad_state
	info.model = response.model
	info.connection_type = response.connection_type
	info.pad_mac_address = ffi.string(response.pad_mac_address, 6)
	info.battery_status = response.battery_status

	return self:listPortsCallback(info)
end

DsuClient.handlePadDataResponse = function(self)
	local response = dsu.pad_data_response
	local padData = self.padData

	padData[response.dsu_shared_response.pad_id + 1] = padData[response.dsu_shared_response.pad_id + 1] or {}

	local data = padData[response.dsu_shared_response.pad_id + 1]
	data.pad_id = response.dsu_shared_response.pad_id
	data.pad_state = response.dsu_shared_response.pad_state
	data.model = response.dsu_shared_response.model
	data.connection_type = response.dsu_shared_response.connection_type
	data.pad_mac_address = ffi.string(response.dsu_shared_response.pad_mac_address, 6)
	data.battery_status = response.dsu_shared_response.battery_status

	data.active = response.active
	data.hid_packet_counter = response.hid_packet_counter
	data.button_states1 = response.button_states1
	data.button_states2 = response.button_states2
	data.button_ps = response.button_ps
	data.button_touch = response.button_touch
	data.left_stick_x = response.left_stick_x
	data.left_stick_y_inverted = response.left_stick_y_inverted
	data.right_stick_x = response.right_stick_x
	data.right_stick_y_inverted = response.right_stick_y_inverted
	data.button_dpad_left_analog = response.button_dpad_left_analog
	data.button_dpad_down_analog = response.button_dpad_down_analog
	data.button_dpad_right_analog = response.button_dpad_right_analog
	data.button_dpad_up_analog = response.button_dpad_up_analog
	data.button_square_analog = response.button_square_analog
	data.button_cross_analog = response.button_cross_analog
	data.button_circle_analog = response.button_circle_analog
	data.button_triangle_analog = response.button_triangle_analog
	data.button_r1_analog = response.button_r1_analog
	data.button_l1_analog = response.button_l1_analog
	data.trigger_r2 = response.trigger_r2
	data.trigger_l2 = response.trigger_l2
	data.dsu_touch1 = response.dsu_touch1
	data.dsu_touch2 = response.dsu_touch2
	data.timestamp_us = response.timestamp_us
	data.accelerometer_x_g = response.accelerometer_x_g
	data.accelerometer_y_g = response.accelerometer_y_g
	data.accelerometer_z_g = response.accelerometer_z_g
	data.gyro_pitch_deg_s = response.gyro_pitch_deg_s
	data.gyro_yaw_deg_s = response.gyro_yaw_deg_s
	data.gyro_roll_deg_s = response.gyro_roll_deg_s

	return self:padDataRequestCallback(data)
end

return DsuClient
