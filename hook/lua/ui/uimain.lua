


function NoteGameSpeedChanged(clientIndex, newSpeed)

    --ORIGINAL FUNCTION DISABLED BECAUSE MY MOD WOULD SPAM IT
    --[[
        local clients = GetSessionClients()
        local client = clients[clientIndex]
        -- Note: this string has an Engine loc tag because it was
        -- originally in the engine.  If we were not already past the loc
        -- deadline, I'd change to to be some UI loc tag.  But we are, so
        -- I'm not going to change it and risk the wrath of the producers.
        print(LOCF("<LOC Engine0006>%s: adjusting game speed to %+d", client.name, newSpeed))
        import("/lua/ui/game/score.lua").NoteGameSpeedChanged(newSpeed)
        import('/lua/ui/game/objectives2.lua').NoteGameSpeedChanged(newSpeed)
    ]]

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
        print(LOCF(CheatsEnabled))
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