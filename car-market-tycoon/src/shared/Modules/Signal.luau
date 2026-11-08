-- Minimal signal implementation (connect / once / fire / wait).
local Signal = {}
Signal.__index = Signal

export type Connection = { Connected: boolean, Disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local connection
	connection = {
		Connected = true,
		Disconnect = function()
			connection.Connected = false
			local index = table.find(self._handlers, connection)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
	connection.Fn = fn
	table.insert(self._handlers, connection)
	return connection
end

function Signal:Once(fn: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, connection in table.clone(self._handlers) do
		if connection.Connected then
			task.spawn(connection.Fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
