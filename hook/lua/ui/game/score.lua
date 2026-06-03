
-- make speed slider work in replays

---@type function
local OriginalSetupPlayerLines = SetupPlayerLines

function SetupPlayerLines()
    OriginalSetupPlayerLines()
end

function ChangeSlider(newValue)
    observerLine.speedSlider:SetValue(newValue)
end
