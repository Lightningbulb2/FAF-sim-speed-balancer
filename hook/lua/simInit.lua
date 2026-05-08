
local oldBeginSession = BeginSession
function BeginSession()
    oldBeginSession()

    ForkThread(function() 
		while true do
			import('/mods/FAF-sim-speed-balancer/modules/global-invoke.lua')
			import('/mods/FAF-sim-speed-balancer/modules/sim-invoke.lua').OnTick()
			WaitTicks(1)
		end
	end)
end
