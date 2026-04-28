
---@type function
local OriginalSetLayout = SetLayout


--Add new UI readouts
function SetLayout()
    OriginalSetLayout()

    local controls = import("/lua/ui/game/score.lua").controls

    LayoutHelpers.RightOf(controls.slowdownText, controls.timeIcon, 102)

    LayoutHelpers.RightOf(controls.speedupText, controls.slowdownText)

end
