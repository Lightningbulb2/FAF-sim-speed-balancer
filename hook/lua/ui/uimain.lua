


-- only show game speed change alerts when it is done by the player
---@type function
local OriginalNoteGameSpeedChanged = NoteGameSpeedChanged
function NoteGameSpeedChanged(clientIndex, newSpeed)

    if import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').CheatsEnabled() and import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').GetPlayerSpeed() ~=0 then
        OriginalNoteGameSpeedChanged(clientIndex, newSpeed)
    end

end


-----
-----Restrict speed adjustments to cheats only instead of "adjustable"
-----

---@type function
local OriginalIncreaseGameSpeed = IncreaseGameSpeed

function IncreaseGameSpeed()
    if import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').CheatsEnabled() then
        OriginalIncreaseGameSpeed()

       	import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').IncreasePlayerSpeed()
    else
        --LOG2("Player increase speed cancelled")
        print(LOCF("Sim Speed Balancer: Speed adjustments are locked without cheats on"))
    end
end

---@type function
local OriginalDecreaseGameSpeed = DecreaseGameSpeed

function DecreaseGameSpeed()
    if import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').CheatsEnabled() then
        OriginalDecreaseGameSpeed()

       	import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').DecreasePlayerSpeed()
    else
        --LOG2("Player decrease speed cancelled")
        print(LOCF("Sim Speed Balancer: Speed adjustments are locked without cheats on"))
    end

end