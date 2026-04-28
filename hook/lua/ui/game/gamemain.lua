local oldCreateUI = CreateUI
function CreateUI(isReplay)
	oldCreateUI(isReplay)

	AddBeatFunction(function() 
		import('/mods/FAF-sim-speed-balancer/modules/global-invoke.lua')
        import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').OnBeat()
    end)
end 

