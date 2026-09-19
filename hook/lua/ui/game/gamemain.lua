local oldCreateUI = CreateUI
function CreateUI(isReplay)
    oldCreateUI(isReplay)
    _G.SimSpeedBalancerPath = "/mods/FAF-sim-speed-balancer"
	import(SimSpeedBalancerPath .. '/modules/global-invoke.lua')

    local uiInvoke = import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua')
	AddBeatFunction(function() 
        uiInvoke.OnBeat()
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

