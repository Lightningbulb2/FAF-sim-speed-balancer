
local function InitMyMod()
    import('/lua/ui/game/gamemain.lua').AddOnSyncCallback(function(sync)
        if sync.timePerTick then
			_G.avgTimePerTick10 = sync.timePerTick.avgTimePerTick10
        end
    end, "MyModSyncCallback")
end



local oldCreateUI = CreateUI
function CreateUI(isReplay)
	oldCreateUI(isReplay)
	InitMyMod()

	AddBeatFunction(function() 
		import('/mods/FAF-sim-speed-balancer/modules/global-invoke.lua')
        import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').OnBeat()
    end)
end 

