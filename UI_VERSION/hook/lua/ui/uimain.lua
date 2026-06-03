


-- only show game speed change alerts when it is done by the player
---@type function
local OriginalNoteGameSpeedChanged = NoteGameSpeedChanged
function NoteGameSpeedChanged(clientIndex, newSpeed)

    if import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').CheatsEnabled() and import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').GetPlayerSpeed() ~=0 then
        OriginalNoteGameSpeedChanged(clientIndex, newSpeed)
    end

end


-----
-----Restrict speed adjustments to cheats only instead of "adjustable"
-----

---@type function
local OriginalIncreaseGameSpeed = IncreaseGameSpeed

function IncreaseGameSpeed()
    if import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').CheatsEnabled() or SessionIsReplay() then

        OriginalIncreaseGameSpeed()
       	import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').IncreasePlayerSpeed()

        
        if SessionIsReplay() then
            import('/lua/ui/game/score.lua').ChangeSlider(import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').GetPlayerSpeed())
        end

    else
        print(LOCF("Sim Speed Balancer: Speed adjustments are locked without cheats on"))
    end
end

---@type function
local OriginalDecreaseGameSpeed = DecreaseGameSpeed

function DecreaseGameSpeed()
    if import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').CheatsEnabled() or SessionIsReplay()  then

        OriginalDecreaseGameSpeed()
       	import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').DecreasePlayerSpeed()
        if SessionIsReplay() then
            import('/lua/ui/game/score.lua').ChangeSlider(import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').GetPlayerSpeed())
        end

    else
        print(LOCF("Sim Speed Balancer: Speed adjustments are locked without cheats on"))
    end

end