--NOTE: running a solo, afk, empty setons clutch for 46:21 resulted in 1:23 of lost time. (97% the speed of realtime)
local options = SessionGetScenarioInfo().Options

----------MODIFY CONSTANTS HERE---------------
----------------------------------------------

-- max length the slow time buffer can hold (ex: =5 means freezing for 10 seconds will only fast forward until 5 seconds is recovered)
local maxRecoveryLength = tonumber(options.SSB_MaxRecovery) or 3.0


local targetTickrate = tonumber(options.SSB_TargetTickrate) or 1


----------------------------------------------
----------------------------------------------

-- TODO: make the debug toggle silently set everyone's game (for performance testing)

local LayoutHelpers = import("/lua/maui/layouthelpers.lua")
local UIUtil = import("/lua/ui/uiutil.lua")
local Tooltip = import("/lua/ui/game/tooltip.lua")
local Bitmap = import("/lua/maui/bitmap.lua").Bitmap
controls = import("/lua/ui/controls.lua").Get()
local Group = import("/lua/maui/group.lua").Group

savedParent = false
local createdUI = false

local lastRealTime = nil
local lastSimTime = nil

local timeOffset = nil
local tickOffset = nil

local currentDivergence = 0.0

local totalSlowdown = 0.0 -- yellow clock
local totalSpeedup = 0.0 -- green clock

_G.avgTimePerTick10 = 0

-------------------------------------
-- used for keeping track of the player's set game speed for overriding the mod when cheats are on, or in a replay
local playerSetSpeed = 0

local decreaseSpeed = false
local increaseSpeed = false

local lastSetModSpeed = 0
local gameSpeed = 0

local modEnabled = true
-------------------------------------


local tickTimeHistory = {}
local tickNumHistory = {}
local tickHistoryMaxSize = 100

local totalTPS = 0


local firstTickTime = 0.0
local firstTickNumber = 0

local currentGameTick =0

local currentRealTime = CurrentTime()
local currentSimTime = GetGameTimeSeconds()

---@type boolean
local wasPaused = false

local gameSpeedOption = SessionGetScenarioInfo().Options.GameSpeed or 0


local SimSpeedBalancerDisplay = nil

function OnBeat()
	local a, b = pcall(function()

		if not SimSpeedBalancerDisplay then
			SimSpeedBalancerDisplay = true
			CreateReadoutsDisplay(GetFrame(0))
		else if controls.SSBbg then
				local tps10 = rawget(_G, "avgTimePerTick10")
				if tps10 then
					controls.avgTickrate:SetText(string.format("%03.1f", tps10))
				end
				controls.slowdownText:SetText(getTotalSlowdown())
				controls.speedupText:SetText(getTotalSpeedup())
			end
		end

		currentGameTick = GameTick()

		currentRealTime = CurrentTime()

		currentSimTime = GetGameTimeSeconds()


		-- Offset the times to be the same (makes comparisons easier)
		if not tickOffset and not timeOffset and currentRealTime and currentSimTime then
			timeOffset = currentRealTime
			tickOffset = currentSimTime
		end

		if timeOffset then
			currentRealTime = (currentRealTime - timeOffset)
		end

		if  tickOffset and currentSimTime then
			currentSimTime = currentSimTime - tickOffset
		end



		--non-working warning
		if currentSimTime < 5 and gameSpeedOption ~= 'adjustable' and not CheatsEnabled() then
			print(LOCF("WARNING: Sim Speed Balancer requires Game Speed set to Adjustable! (Readouts still work without that though)"))
		end


		if playerSetSpeed ~= 0 and playerSetSpeed ~= GetGameSpeed() and not increaseSpeed and not decreaseSpeed then
			playerSetSpeed = GetGameSpeed()
			if SessionIsReplay() then
				import('/lua/ui/game/score.lua').ChangeSlider(GetGameSpeed())
			end
		end


		if lastRealTime and lastSimTime and not wasPaused and not SessionIsPaused() then

			local realDelta = (currentRealTime) - lastRealTime
			realDelta = realDelta*targetTickrate
			local simDelta = (currentSimTime - lastSimTime)

			
			local divergenceDelta = (realDelta)-simDelta
		
			
			
				
				-- SLOW TICKS
	
				local maximumAmount = maxRecoveryLength - currentDivergence

				--  accumulate slow and fast ticks (current divergence of real time and sim time)
				if  divergenceDelta < maximumAmount and playerSetSpeed == 0 then
					currentDivergence = currentDivergence + divergenceDelta
					
				elseif divergenceDelta >=maximumAmount and playerSetSpeed == 0 then
					currentDivergence = currentDivergence + maximumAmount
				end

					

				--accumulate slowticks for readouts (time lost)
				if realDelta > simDelta and not currentDivergence <= 0.1 and playerSetSpeed == 0 then
					-- +=
					totalSlowdown = totalSlowdown + divergenceDelta
				
				-- accumulate fast ticks (time saved)
				elseif realDelta < simDelta and not currentDivergence <= 0.1 and playerSetSpeed == 0 then
					-- -=
					totalSpeedup = totalSpeedup + divergenceDelta
				end

				if currentDivergence <= 0.1 then
					gameSpeed = 0
				end
				
				if currentDivergence > 0.1 then

					gameSpeed = 1
					
					-- go a little faster for the tick immediately following a slow tick why not
					if divergenceDelta > 0.035 then
						gameSpeed = 2
					end
					if divergenceDelta > 0.05 then
						gameSpeed = 3
					end
					
				end

				if increaseSpeed and (lastSetModSpeed == 1 or lastSetModSpeed == 2 or lastSetModSpeed == 3) then
					SetGameSpeed(1)
					playerSetSpeed = 1
					increaseSpeed = false
				end
				if decreaseSpeed and (lastSetModSpeed == 1 or lastSetModSpeed == 2 or lastSetModSpeed == 3) then
					SetGameSpeed(-1)
					playerSetSpeed = -1
					decreaseSpeed = false
				end


				if playerSetSpeed == 0 and modEnabled then
					SetGameSpeed(gameSpeed)
				end

		end


		if playerSetSpeed == 0 then
			lastSetModSpeed = gameSpeed
		else
			lastSetModSpeed = -100
		end



		if not SessionIsReplay() and currentGameTick and GetGameTimeSeconds() then

			if firstTickTime then

				--get time since beginning
				local deltaTime = currentRealTime - firstTickTime

				--time divided by tick distance
				--because deltaTime is called AT THE CURRENT TICK RATE, we need to adjust the delta by how many ticks have ACTUALLY passed or else it's assumed the game is running at 10tps
				realDelta = deltaTime/(currentGameTick - firstTickNumber)

				totalTPS = 1/realDelta

			end


			_G.avgTimePerTick10 = getTicksPerSecond(100)
			


			--LOG2(string.format("TPS (5s): %015.12f  TPS (10s): %015.12f TPS (TOTAL): %015.12f", getTicksPerSecond(50),getTicksPerSecond(100), totalTPS ))


			if not wasPaused then
				arrayQueuePush(tickTimeHistory, currentRealTime, tickHistoryMaxSize)
				arrayQueuePush(tickNumHistory, currentGameTick, tickHistoryMaxSize)
			end

			if not firstTickTime or not firstTickNumber and GetGameTimeSeconds() > 5 then
				firstTickTime = currentRealTime
				firstTickNumber = currentGameTick
			end



		end

		decreaseSpeed = false
		increaseSpeed = false

		lastRealTime = currentRealTime
		lastSimTime = currentSimTime
		wasPaused = false

		
	end)

	if not a then LOG2(b) end
end

function toggleEnabled()
	if modEnabled then
		modEnabled = false
		print(LOCF("Sim Speed Balancer: disabled"))
		SetGameSpeed(0)
	else
		modEnabled = true
		print(LOCF("Sim Speed Balancer: enabled"))
	end
	
end

function ModSetGamePaused(bool)
	wasPaused = bool
end

function getTotalSlowdown()
	return FormatTime(totalSlowdown)
end
function getTotalSpeedup()
	return FormatTime(math.abs(totalSpeedup))
end

function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
	local m = math.floor(math.mod(seconds, 3600) / 60)
	local s = math.floor(math.mod(seconds, 60))
    return string.format(" %02d:%02d:%02d", h, m, s)
end

function IncreasePlayerSpeed()
	increaseSpeed = true
	--LOG("IncreasePlayerSpeed")
	playerSetSpeed = playerSetSpeed + 1
end

function SetPlayerSpeed(speed)
	--LOG("SetPlayerSpeed")
	playerSetSpeed = speed
end

function DecreasePlayerSpeed()
	--LOG("DecreasePlayerSpeed")
	decreaseSpeed = true

	playerSetSpeed = playerSetSpeed - 1
end

function GetPlayerSpeed()
	return playerSetSpeed
end


function CheatsEnabled()
	if SessionIsActive() then
		local cheatStatus = SessionGetScenarioInfo().Options.CheatsEnabled
		if cheatStatus == "true" then
			return true
		else
			return false
		end
	end
end

---@param tickWindow integer
function getTicksPerSecond(tickWindow)

	local ticksPerSecond  = 0

	local currentArraySize = table.getn(tickTimeHistory)

	if currentArraySize >= tickWindow and tickWindow <= tickHistoryMaxSize then

		local deltaTime = currentRealTime - tickTimeHistory[tickWindow]

		local tickDelta = currentGameTick - tickNumHistory[tickWindow]
		if tickDelta == 0 then return 0 end
		--time divided by tick distance
		--(this code is called AT THE CURRENT TICK RATE, so we need to make sure we have actually progressed a tick) or else it's assumed the game is running at 10tps
		realDelta = deltaTime/(currentGameTick - tickNumHistory[tickWindow])


		ticksPerSecond = 1/realDelta
	end

	if tickWindow > tickHistoryMaxSize then
		LOG2("Tick window too large, increase the tickHistoryMaxSize")
	end


	return ticksPerSecond

end


---@param array table
---@param element any
---@param limit integer
function arrayQueuePush(array, element, limit)
	
	local length = table.getn(array)

	if length >= limit then
		table.remove(array, length)
	end
	table.insert(array, 1, element)

end



function CreateReadoutsDisplay(parent)
	createdUI = true

	controls.SSBbg = Group(parent)
    controls.SSBbg.Depth:Set(10)
	LayoutHelpers.AtLeftTopIn(controls.SSBbg, parent, 1200, 10)

	controls.SSBbg.main = Group(controls.SSBbg)
	LayoutHelpers.AtLeftTopIn(controls.SSBbg.main, controls.SSBbg, 0, 0)


	controls.SSBbgTop = Bitmap(controls.SSBbg)
    controls.SSBbgTop:SetTexture(UIUtil.UIFile('/game/score-panel/panel-score_bmp_b.dds'))
    LayoutHelpers.AtLeftTopIn(controls.SSBbgTop, controls.SSBbg, -13, 18)
    controls.SSBbgTop.Width:Set(175)
	controls.SSBbgTop.Height:Set(-15)


	controls.SSBbgBottom = Bitmap(controls.SSBbg)
    controls.SSBbgBottom:SetTexture(UIUtil.UIFile('/game/score-panel/panel-score_bmp_b.dds'))
    LayoutHelpers.AtLeftTopIn(controls.SSBbgBottom, controls.SSBbg, -13, 18)
    controls.SSBbgBottom.Width:Set(175)
	controls.SSBbgBottom.Height:Set(15)

	controls.SSBbg.main.Height:Set(35)
    controls.SSBbg.main.Width:Set(150)

	LayoutHelpers.SetDimensions(controls.SSBbg, 0, 0)
    controls.SSBcollapseArrow = UIUtil.CreateCollapseArrow(controls.SSBbg, "t")
	controls.SSBcollapseArrow:EnableHitTest(true)
    controls.SSBcollapseArrow.OnCheck = function(self, checked)
        ToggleReadouts(not checked)
    end
    Tooltip.AddCheckboxTooltip(controls.SSBcollapseArrow,  {
    	text = "Collapse/Expand"})

	controls.tickRateReadout = UIUtil.CreateText(controls.SSBbg.main, "(10s) TPS:", 12, UIUtil.bodyFont, true)
	controls.tickRateReadout:SetColor('ff00C4E2')
	controls.tickRateReadout:EnableHitTest(true)

    controls.avgTickrate = UIUtil.CreateText(controls.SSBbg.main, '00.0', 13, UIUtil.bodyFont, true)
    controls.avgTickrate:SetColor('ff00dbff')
	controls.avgTickrate:EnableHitTest(true)
	Tooltip.AddControlTooltip(controls.avgTickrate, {
    	text = "Tickrate",
    	body = "readout may fluctuate based on game conditions and mod behavior",}, 0)
	Tooltip.AddControlTooltip(controls.tickRateReadout, {
    	text = "Tickrate",
    	body = "readout may fluctuate based on game conditions and mod behavior",}, 0)

	local str = string.format("/ %03.1f", targetTickrate*10)

    controls.targTickrate = UIUtil.CreateText(controls.SSBbg.main, str, 9.5, UIUtil.bodyFont, true)
    controls.targTickrate:SetColor('ff00C4E2')
	controls.targTickrate:EnableHitTest(true)
	Tooltip.AddControlTooltip(controls.targTickrate, {
    	text = "Target Tickrate",
    	body = "Lobby set minimum tickrate",}, 0.1)

	

    controls.slowdownText = UIUtil.CreateText(controls.SSBbg.main, '00:00:00', 11, UIUtil.bodyFont, true)
    controls.slowdownText:SetColor('ffffff00')
	controls.slowdownText:EnableHitTest(true)

    Tooltip.AddControlTooltip(controls.slowdownText, {
    	text = "Slow Time",
    	body = "The total time the sim is behind real time since starting",},0)

    controls.speedupText = UIUtil.CreateText(controls.SSBbg.main, '00:00:00', 11, UIUtil.bodyFont, true)
    controls.speedupText:SetColor('ff00ff00')
	controls.speedupText:EnableHitTest(true)
    Tooltip.AddControlTooltip(controls.speedupText, {
    	text = "Fast Time",
		body = "The total time that has been recouped from Slow Time",}, 0)

	controls.SimSpeedBalancerInfo = UIUtil.CreateText(controls.SSBbg.main, 'Sim Speed Balancer info', 10, UIUtil.bodyFont, true)
    controls.SimSpeedBalancerInfo:SetColor('AAAAAA')

	LayoutHelpers.AtLeftTopIn(controls.tickRateReadout, controls.SSBbg.main, -5, 10)

    LayoutHelpers.AtRightTopIn(controls.avgTickrate, controls.SSBbg.main, 66, 7)
	LayoutHelpers.AtLeftTopIn(controls.targTickrate, controls.tickRateReadout, 64, 10)

    LayoutHelpers.AtLeftTopIn(controls.slowdownText, controls.SSBbg.main, 105, (6))

    LayoutHelpers.AtLeftTopIn(controls.speedupText, controls.slowdownText, 0, (11))

	LayoutHelpers.AtLeftTopIn(controls.SSBcollapseArrow, controls.SSBbg, 0, -15)

	LayoutHelpers.AtLeftTopIn(controls.SimSpeedBalancerInfo, controls.SSBbg.main, 30, -10)

end



function ToggleReadouts(checked)

    -- disable when in Screen Capture mode
    if import("/lua/ui/game/gamemain.lua").gameUIHidden then
        return
    end

    if not controls.SSBbg.main then
        return
    end

	if createdUI then
        if checked then
            controls.SSBbg.main:Show()
			controls.SSBbgTop:Show()
			controls.SSBbgBottom:Show()
            local sound = Sound({Cue = "UI_Score_Window_Open", Bank = "Interface",})
            PlaySound(sound)

		else
			local sound = Sound({Cue = "UI_Score_Window_Close", Bank = "Interface",})
			PlaySound(sound)
			controls.SSBbg.main:Hide()
			controls.SSBbgTop:Hide()
			controls.SSBbgBottom:Hide()

        end

    end

end

