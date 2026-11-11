--!nonstrict
-- Signal minimal tanpa dependensi (pengganti sleitnick/signal untuk Fase 0).

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {}, _next = 1 }, Signal)
end

function Signal:Connect(fn)
	local id = self._next
	self._next += 1
	self._handlers[id] = fn
	return {
		Disconnect = function()
			self._handlers[id] = nil
		end,
	}
end

function Signal:Fire(...)
	for _, fn in self._handlers do
		task.spawn(fn, ...)
	end
end

return Signal
