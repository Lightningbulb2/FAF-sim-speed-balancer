
local oldBeginSession = BeginSession
function BeginSession()
    oldBeginSession()

    ForkThread(function() 
		while true do
			import('/mods/FAF_sim_speed_balancer/modules/global-invoke.lua')
			import('/mods/FAF_sim_speed_balancer/modules/sim-invoke.lua').OnTick()
			WaitTicks(1)
		end
	end)
end
