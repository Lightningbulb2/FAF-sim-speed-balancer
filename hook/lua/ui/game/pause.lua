
---@type function
local originalOnResume = OnResume

--- Inform the mod that the last halt was just a pause
function OnResume()
    originalOnResume()
    import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').ModSetGamePaused(true)
end