local oldCreateUI = CreateUI
function CreateUI(isReplay)
	oldCreateUI(isReplay)
    _G.SimSpeedBalancerPath = "/mods/FAF-sim-speed-balancer"
		import(SimSpeedBalancerPath .. '/modules/global-invoke.lua')
    local simModUID = 'fa45244b-3fd5-490b-99a5-b7f5e4631d4c'
    local simModActive = false

    for _, mod in _G.__active_mods do
        if mod.uid == simModUID then
            simModActive = true
            break
        end
    end

    if not simModActive then
        AddBeatFunction(function() 
            import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').OnBeat()
        end)

    end
end 

