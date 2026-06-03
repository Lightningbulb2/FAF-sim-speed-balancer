
---@type function
local originalOnResume = OnResume

--- Inform the mod that the last halt was just a pause
function OnResume()
    originalOnResume()
    import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').ModSetGamePaused(true)
end




_G.SessionResume = function()
    local localClientIndex, clientData = FindLocalClient()
    local timeDifference = GetSystemTimeSeconds() - OnPauseTimestamp

    -- conditions that allow an immediate resume of the session
    if SessionIsReplay() or
        not SessionIsMultiplayer() or
        OnPauseClientIndex == localClientIndex or -- feature: the person who initiated the pause can resume at any time
        timeDifference > ResumeThreshold -- feature: any person can resume after the pause lasted past the threshold
    then
        SessionSendChatMessage({ SendResumedBy = true })
        oldSessionResume()
        import(SimSpeedBalancerPath .. '/modules/ui-invoke.lua').ModSetGamePaused(true)
        return 'Accepted'
    else
        -- inform other clients
        SessionSendChatMessage(import('/lua/ui/game/clientutils.lua').GetAll(), {
            to = 'all',
            text = string.format('Wants to resume the game but has to wait %d seconds', ResumeThreshold - timeDifference),
            Chat = true,
        })

        return 'Declined'
    end
end