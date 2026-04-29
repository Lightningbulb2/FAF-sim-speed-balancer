
---@type function
local OriginalSetLayout = SetLayout


--Add new UI readouts
function SetLayout()
    OriginalSetLayout()

    local controls = import("/lua/ui/game/score.lua").controls

    LayoutHelpers.AtLeftTopIn(controls.slowdownText, controls.timeIcon, 160, (-4))

    LayoutHelpers.AtLeftTopIn(controls.speedupText, controls.slowdownText, 0, (11))

    LayoutHelpers.AtLeftTopIn(controls.gameQuality , controls.timeIcon, (114), 1)

end
