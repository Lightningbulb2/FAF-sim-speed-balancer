-- wrap log function in a way that we can find it easily in the log (by FAF-sim-speed-balancer key)
_G.LOG2 = function(a)
	LOG("FAF-sim-speed-balancer:", a)
end

_G.LogTable = function(o)
	if o == nil then return LOG2("nil") end
	for k, v in o do
		LOG2(k .. " = " .. tostring(v))
	end
end
