--[[

---@type function
local OriginalCreateScoreUI = CreateScoreUI


--
function CreateScoreUI(parent)
    OriginalCreateScoreUI(parent)

    controls.slowdownText = UIUtil.CreateText(controls.bgTop, '0', 12, UIUtil.bodyFont)
    slowdownText:SetColor('ffff0000')  -- AARRGGBB format, this is RED

    controls.speedupText = UIUtil.CreateText(controls.bgTop, '0', 12, UIUtil.bodyFont)
    speedupText:SetColor('ff00ff00')  -- AARRGGBB format, this is green
    
end
]]

-- NEEDED to overwrite entire function to insert my UI code in the right spot
function CreateScoreUI(parent)
    created = true
    savedParent = GetFrame(0)

    controls.bg = Group(savedParent)
    controls.bg.Depth:Set(10)

    controls.collapseArrow = Checkbox(savedParent)
    controls.collapseArrow.OnCheck = function(self, checked)
        ToggleScoreControl(not checked)
    end
    Tooltip.AddCheckboxTooltip(controls.collapseArrow, 'score_collapse')

    controls.bgTop = Bitmap(controls.bg)
    controls.bgBottom = Bitmap(controls.bg)
    controls.bgStretch = Bitmap(controls.bg)
    controls.armyGroup = Group(controls.bg)

    controls.leftBracketMin = Bitmap(controls.bg)
    controls.leftBracketMax = Bitmap(controls.bg)
    controls.leftBracketMid = Bitmap(controls.bg)

    controls.rightBracketMin = Bitmap(controls.bg)
    controls.rightBracketMax = Bitmap(controls.bg)
    controls.rightBracketMid = Bitmap(controls.bg)

    controls.leftBracketMin:DisableHitTest()
    controls.leftBracketMax:DisableHitTest()
    controls.leftBracketMid:DisableHitTest()
    controls.rightBracketMin:DisableHitTest()
    controls.rightBracketMax:DisableHitTest()
    controls.rightBracketMid:DisableHitTest()

    controls.bg:DisableHitTest(true)

    LayoutHelpers.SetWidth(controls.bgTop, 320)

    controls.time = UIUtil.CreateText(controls.bgTop, '0', 12, UIUtil.bodyFont)
    controls.time:SetColor('ff00dbff')
    controls.timeIcon = Bitmap(controls.bgTop)
    Tooltip.AddControlTooltip(controls.timeIcon, 'score_time')
    Tooltip.AddControlTooltip(controls.time, 'score_time')
    controls.unitIcon = Bitmap(controls.bgTop)
    Tooltip.AddControlTooltip(controls.unitIcon, 'score_units')
    controls.units = UIUtil.CreateText(controls.bgTop, '0', 12, UIUtil.bodyFont)
    controls.units:SetColor('ffff9900')
    Tooltip.AddControlTooltip(controls.units, 'score_units')

    ---------------------------------------------------
    ----------ONLY CODE I ADDED------------------------
    ---------------------------------------------------
    controls.slowdownText = UIUtil.CreateText(controls.bgTop, '0', 11, UIUtil.bodyFont)
    controls.slowdownText:SetColor('ffffff00')  -- AARRGGBB format, this is RED
    Tooltip.AddControlTooltip(controls.slowdownText, 'score_slow_time')

    controls.speedupText = UIUtil.CreateText(controls.bgTop, '0', 11, UIUtil.bodyFont)
    controls.speedupText:SetColor('ff00ff00')  -- AARRGGBB format, this is green
    Tooltip.AddControlTooltip(controls.speedupText, 'score_fast_time')
    ---------------^^^----------------------------------
    ----------ONLY CODE I ADDED------------------------
    ---------------------------------------------------

    SetLayout()
    SetupPlayerLines()
    controls.armyGroup.Height:Set(armyGroupHeight())
    scoreMini.LayoutArmyLines()

    GameMain.AddBeatFunction(_OnBeat, true)
    controls.bg.OnDestroy = function(self)
        GameMain.RemoveBeatFunction(_OnBeat)
    end

    if contractOnCreate then
        Contract()
    end

    controls.bg:SetNeedsFrameUpdate(true)
    controls.bg.OnFrame = function(self, delta)
        local newRight = self.Right() + (1000*delta)
        if newRight > savedParent.Right() + self.Width() then
            newRight = savedParent.Right() + self.Width()
            self:Hide()
            self:SetNeedsFrameUpdate(false)
        end
        self.Right:Set(newRight)
    end

    controls.collapseArrow:SetCheck(true, true)
end



--set the new UI readouts
---@type function
local _OriginalOnBeat = _OnBeat

function _OnBeat()

    gameSpeed = import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').GetPlayerSpeed()

    _OriginalOnBeat()
    controls.slowdownText:SetText(import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').getTotalSlowdown())
    controls.speedupText:SetText(import('/mods/FAF-sim-speed-balancer/modules/ui-invoke.lua').getTotalSpeedup())
end


