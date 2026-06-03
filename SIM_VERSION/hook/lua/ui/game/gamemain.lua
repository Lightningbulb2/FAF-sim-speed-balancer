local oldCreateUI = CreateUI
function CreateUI(isReplay)
	oldCreateUI(isReplay)
    _G.SimSpeedBalancerPath = "/mods/FAF-sim-speed-balancer/SIM_VERSION"
		import(SimSpeedBalancerPath .. '/modules/global-invoke.lua')
	AddBeatFunction(function() 
        import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').OnBeat()
    end)

end 

