--Potentially improve upgrade issues?

local OriginalUpgradeUnit = UpgradeUnit

local function UpgradeUnit(unit)
    OriginalUpgradeUnit(unit)

    ---@type UserUnit[]
    local units = { unit }

    local isUpgrading = unit:GetWorkProgress() > 0

    if isUpgrading ~= nil and isUpgrading  < 1 then
        if GetIsPaused(units) then
            SetPaused(units, false)
            WaitTicks(5)
            SetPaused(units, true)
        end
    end
end

local OriginalOnGuardUpgrade = OnGuardUpgrade

local function OnGuardUpgrade(guardees, unit)
    OnGuardUpgrade(guardees, unit)

    local unitBlueprint = unit:GetBlueprint()

     -- check for mass extractors
    local upgradeExtractor = Prefs.GetFieldFromCurrentProfile('options').assist_to_upgrade
    local upgradeExtractorTech1 = upgradeExtractor == 'Tech1Extractors' or upgradeExtractor == 'Tech1Tech2Extractors'
    local upgradeExtractorTech2 = upgradeExtractor == 'Tech1Tech2Extractors'

    if upgradeExtractorTech2 and
        EntityCategoryContains(categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH2, unit)
    then
        ForkThread(UpgradeUnit, unit)
        return
    end

end