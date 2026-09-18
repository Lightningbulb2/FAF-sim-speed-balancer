

-- wrap log function so it's easy to filter in the log
_G.LOG2 = function(a)
	LOG("FAF-sim-speed-balancer:", a)
end

--Utility function for printing tables
_G.LogTable = function(o)
	if o == nil then return LOG2("nil") end
	for k, v in o do
		LOG2(k .. " = " .. tostring(v))
	end
end