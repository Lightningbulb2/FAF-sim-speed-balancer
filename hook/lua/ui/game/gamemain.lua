local oldCreateUI = CreateUI
function CreateUI(isReplay)
	oldCreateUI(isReplay)

	AddBeatFunction(function() 
		import('/mods/FAF_sim_speed_balancer/modules/global-invoke.lua')
        import('/mods/FAF_sim_speed_balancer/modules/ui-invoke.lua').OnBeat()
    end)
end 

