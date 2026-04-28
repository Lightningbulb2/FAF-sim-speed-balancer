-- wrap log function in a way that we can find it easily in the log (by FAF_sim_speed_balancer key)
_G.LOG2 = function(a)
	LOG("FAF_sim_speed_balancer:", a)
end

_G.LogTable = function(o)
	if o == nil then return LOG2("nil") end
	for k, v in o do
		LOG2(k .. " = " .. tostring(v))
	end
end
