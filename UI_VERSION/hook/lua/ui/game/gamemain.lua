local oldCreateUI = CreateUI
function CreateUI(isReplay)
    oldCreateUI(isReplay)
    _G.SimSpeedBalancerPath = "/mods/FAF-sim-speed-balancer/UI_VERSION"
	import(SimSpeedBalancerPath .. '/modules/global-invoke.lua')

    local simModUID = '2086e2dc-c049-4928-958e-6e0ac590d548'
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

        InitSimSpeedBalancer(isReplay)
    end 

    -- Apply mod toggle to everyone
    function InitSimSpeedBalancer(isReplay)

        
        RegisterChatFunc(function(player, msg)
            if player then
                -- Update Data State
                local enabled = msg.data
                if enabled ~= nil then
                    if enabled then
                        import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').ToggleEnabledOn()
                    else
                        import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').ToggleEnabledOff()
                    end
                end
                local modVersion = msg.version

                if modVersion then
                    import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').HasSimSpeedBalancer(player, modVersion)
                end

            end
        end, 'SimSpeedBalancer') 
    end
end
