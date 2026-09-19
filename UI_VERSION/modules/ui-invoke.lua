--TODO: deal with annoying reset speed bind that goes straight to the engine from "*"

-- Initialize queue structure
---@param maxLimit integer
function CreateRingQueue(maxLimit)
    return {
        items = {},
        head = 1,       -- Read pointer (points to the oldest item)
        tail = 1,       -- Write pointer (where the NEXT item will be written)
        limit = maxLimit,
        count = 0
    }
end

-- Push elements with O(1) performance (Lossy Ring Queue)
---@param queue table
---@param element any
function RingQueuePush(queue, element)
    -- Insert the element at the current tail position
    queue.items[queue.tail] = element
    
    -- Move the tail forward
    queue.tail = queue.tail + 1
    
    -- Wrap the tail back to index 1 if it passes the limit
    if queue.tail > queue.limit then
        queue.tail = 1
    end
    
    -- Handle the lossy overwrite logic
    if queue.count < queue.limit then
        -- Queue is not full yet, just increase the count
        queue.count = queue.count + 1
    else
        -- Queue is full. We just overwrote the oldest item.
        -- Nudge the head forward so it correctly points to the NEW oldest item.
        queue.head = queue.head + 1
        if queue.head > queue.limit then
            queue.head = 1
        end
    end
end

--#region Constants

local modVersion = 20

local OPTIONS = SessionGetScenarioInfo().Options

local GAMESPEED_OPTION = OPTIONS.GameSpeed or 0


-- max length the slow time buffer can hold (ex: =5 means freezing for 10 seconds will only fast forward until 5 seconds is recovered)
local MAX_RECOVERY_LENGTH = tonumber(OPTIONS.SSB_MaxRecovery) or 3.0


local TARGET_TICKRATE = tonumber(OPTIONS.SSB_TargetTickrate) or 1

local TOGGLE_PLAYER = tonumber(OPTIONS.SSB_TogglePlayer) or 1

local LOGGING_ENABLED = tonumber(OPTIONS.SSB_Logging) or 0


local armies = GetArmiesTable().armiesTable
myArmyId = GetFocusArmy()
local myName = armies[myArmyId].nickname

local validClients = {}
local moddedClients = {}

--#endregion


--#region UI variables
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")
local UIUtil = import("/lua/ui/uiutil.lua")
local Tooltip = import("/lua/ui/game/tooltip.lua")
local Bitmap = import("/lua/maui/bitmap.lua").Bitmap
controls = import("/lua/ui/controls.lua").Get()
local Group = import("/lua/maui/group.lua").Group
local ChatController = import('/lua/ui/game/chat/ChatController.lua')


local createdUI = false


local tickHistoryMaxSize = 100

local tickTimeHistory = CreateRingQueue(tickHistoryMaxSize)
local tickNumHistory = CreateRingQueue(tickHistoryMaxSize)

--FOR: average TPS since the beginning of the game
--local totalTPS = 0
--local trackTotalTime = false

local totalSlowdown = 0.0 -- yellow clock
local totalSpeedup = 0.0 -- green clock

local avgTimePerTick10 = 0

--#endregion


--#region Mod calculations
local lastRealTime = nil
local lastSimTime = nil

local timeOffset = nil
local tickOffset = nil

local currentDivergence = 0.0

local currentGameTick

local currentRealTime
local currentSimTime

---@type boolean
local wasPaused = false

local fetchedUnknownClients = false

--#endregion


--#region Player game speed override tracking variables
local playerSetSpeed = 0

local decreaseSpeed = false
local increaseSpeed = false

local lastSetModSpeed = 0
local gameSpeed = 0

local modEnabled = true
--#endregion



function OnBeat()
	local a, b = pcall(function()

		currentGameTick = GameTick()
		currentRealTime = CurrentTime()
		currentSimTime = GetGameTimeSeconds()


		--#region return early when paused or uninitialized
		
		-- SessionIsPaused() is required to stop the mod from doing anything before the game actually pauses even though the pause button has been activated
		if SessionIsPaused()
			or not currentRealTime
			or not currentSimTime
			or not currentGameTick then

			return
		end

		--CycleTick and return early if the game was paused (to avoid a huge divergence spike) or there are uninitialized variables
		if not lastRealTime
			or not lastSimTime then
			CycleTickVariables()
			SetGameSpeed(0)
			return
		end
		--#endregion
		
		--#region get tick/time offsets

		-- Offset the times to be the same (makes comparisons easier)
		if not tickOffset and not timeOffset then
			timeOffset = currentRealTime
			tickOffset = currentSimTime
			--reset last times to avoid a huge divergence spike on the first tick
			lastSimTime = 0
			lastRealTime = 0


		end

		if timeOffset then
			currentRealTime = (currentRealTime - timeOffset)
		end

		if  tickOffset then
			currentSimTime = currentSimTime - tickOffset
		end
		
		--#endregion


		--#region calculate divergence

		--returning early on pause causes nasty bugs so we gotta wrap the whole thing instead

			local realDelta = (currentRealTime) - lastRealTime
			realDelta = realDelta*TARGET_TICKRATE
			local simDelta = (currentSimTime - lastSimTime)

			local divergenceDelta = (realDelta)-simDelta

			--Skip divergence spike after super long pauses
			if modEnabled and divergenceDelta > 10 then
				divergenceDelta = 0
				currentDivergence = 0.1
			end

		if not wasPaused then
			local maximumAmount = MAX_RECOVERY_LENGTH - currentDivergence

			--  accumulate slow and fast ticks (current divergence of real time and sim time)
			if  divergenceDelta < maximumAmount and playerSetSpeed == 0 then
				currentDivergence = currentDivergence + divergenceDelta

			elseif divergenceDelta >=maximumAmount and playerSetSpeed == 0 then
				currentDivergence = currentDivergence + maximumAmount
			end



			--accumulate slowticks for readouts (time lost)
			if realDelta > simDelta and currentDivergence > 0.1 and playerSetSpeed == 0 then
				-- +=
				totalSlowdown = totalSlowdown + divergenceDelta

			-- accumulate fast ticks (time saved)
			elseif realDelta < simDelta and currentDivergence > 0.1 and playerSetSpeed == 0 then
				-- -=
				totalSpeedup = totalSpeedup + divergenceDelta
			end
			--#endregion

			--#region Game Speed Selection
			if currentDivergence <= 0.1 then
				gameSpeed = 0
			end

			if currentDivergence > 0.1 then

				gameSpeed = 1

				-- go a little faster for the tick immediately following a slow tick why not
				if divergenceDelta > 0.035 then gameSpeed = 2 end
				if divergenceDelta > 0.05 then gameSpeed = 3 end

			end

			--LOG2(string.format("%015.12f  %015.12f %015.12f  %015.12f %015.12f", currentDivergence, currentGameTick, currentRealTime, currentSimTime, divergenceDelta))
		
		--reset rolling TPS history on pause to avoid sudden readout drop
		elseif wasPaused then
			ClearReadoutHistory()
		end

		--Prevent player speed override from working off of the mod's value (for when cheats are enabled, or in a replay)
		if modEnabled and increaseSpeed and (lastSetModSpeed == 1 or lastSetModSpeed == 2 or lastSetModSpeed == 3) then
			SetGameSpeed(1)
			playerSetSpeed = 1
			increaseSpeed = false
		end
		if modEnabled and decreaseSpeed and (lastSetModSpeed == 1 or lastSetModSpeed == 2 or lastSetModSpeed == 3) then
			SetGameSpeed(-1)
			playerSetSpeed = -1
			decreaseSpeed = false
		end

		-- prevent game speed changes when mod is disabled
		if not modEnabled and not SessionIsReplay() then
			gameSpeed = 0
			playerSetSpeed = 0
		end

		if playerSetSpeed == 0 and not SessionIsReplay() then
			SetGameSpeed(gameSpeed)
			lastSetModSpeed = gameSpeed
		elseif playerSetSpeed == 0 and SessionIsReplay() and modEnabled then
			SetGameSpeed(gameSpeed)
			lastSetModSpeed = gameSpeed
		else
			-- set dummy mod value during override
			lastSetModSpeed = -100
		end
		--#endregion



		--#region UI warning, creation, and readout updates

		--non-working warning
		if currentSimTime < 5 and GAMESPEED_OPTION ~= 'adjustable' and not CheatsEnabled() then
			print(LOCF("WARNING: Sim Speed Balancer requires Game Speed set to Adjustable! (Readouts still work without that though)"))
		end

		if currentGameTick > 50 and not fetchedUnknownClients and not SessionIsReplay() then
			GetUnknownClients()
			fetchedUnknownClients = true
		end


		-- CREATE UI
		if not createdUI then
			CreateReadoutsDisplay(GetFrame(0))
			createdUI = true
		else if controls.SSBbg then
				if avgTimePerTick10 then
					controls.avgTickrate:SetText(string.format("%03.1f", avgTimePerTick10))
				end
				if currentDivergence <= 1 then
					controls.divergenceText:SetColor('ff00ff00')
					controls.divergenceText:SetText(string.format("%03.2fs", currentDivergence))
				
				elseif currentDivergence <= 2 then
					controls.divergenceText:SetColor('ffffff00')
					controls.divergenceText:SetText(string.format("%03.2f", currentDivergence))
				elseif currentDivergence <= 3 then
					controls.divergenceText:SetColor('FFFF0000')
					controls.divergenceText:SetText(string.format("%03.2fs", currentDivergence))
				end

				controls.slowdownText:SetText(GetTotalSlowdown())
				controls.speedupText:SetText(GetTotalSpeedup())
			end
		end

		-- update tick readout (5s)
		if not SessionIsReplay() then

			avgTimePerTick10 = GetTicksPerSecond(50)

			RingQueuePush(tickTimeHistory, currentRealTime)
			RingQueuePush(tickNumHistory, currentGameTick)

		end

		-- change replay slider, and keep known player speed synced (the * keybind sets the game speed to 0 which is engine side so I have to watch it myself)
		if playerSetSpeed ~= 0 and playerSetSpeed ~= GetGameSpeed() and not increaseSpeed and not decreaseSpeed then
			playerSetSpeed = GetGameSpeed() or 0
			if SessionIsReplay() then
				import('/lua/ui/game/score.lua').ChangeSlider(GetGameSpeed())
			end
		end

		--#endregion

		if LOGGING_ENABLED == 1 then
			--LOG2(string.format("Current Divergence %015.12f | Divergence Change %+016.12f | Game Tick %015.12f | Real Time %015.12f | Sim Time %015.12f | Was Paused %d", currentDivergence, divergenceDelta, currentGameTick, currentRealTime, currentSimTime, wasPaused and 1 or 0))

			LOG2(string.format("%d | %06d | %010.3f | %010.3f | %015.12f | %+016.12f",modEnabled and 1 or 0, currentGameTick, currentRealTime, currentSimTime, currentDivergence, divergenceDelta))
		end

		-- set variables for next tick
		CycleTickVariables()

	end)

	if not a then LOG2(b) end
end

--#region Mod Utility functions

function CycleTickVariables()
	decreaseSpeed = false
	increaseSpeed = false

	lastRealTime = currentRealTime
	lastSimTime = currentSimTime
	wasPaused = false
end

function ClearReadoutHistory()
	tickTimeHistory.head = 1
	tickTimeHistory.tail = 1
	tickTimeHistory.count = 0
	tickNumHistory.head = 1
	tickNumHistory.tail = 1
	tickNumHistory.count = 0
end

function ToggleEnabled()

	if GetFocusArmy() ~= TOGGLE_PLAYER and not SessionIsReplay() then
		print("You cannot toggle Sim Speed Balancer")
		return
	end
	if modEnabled then
		ToggleEnabledOff()
		print(LOCF("Sim Speed Balancer: disabled"))

	else
		ToggleEnabledOn()
		print(LOCF("Sim Speed Balancer: enabled"))
	end

	--Apply mod toggle to everyone
	SessionSendChatMessage(validClients, { Identifier = 'SimSpeedBalancer', data = modEnabled })
end

function ToggleEnabledOff()
	if controls.SSBbg then
		controls.SSBstatus:SetText("OFF")
	end
	modEnabled = false
	SetGameSpeed(0)
end

function ToggleEnabledOn()
	if controls.SSBbg then
		controls.SSBstatus:SetText("")
	end
	currentDivergence = 0
	modEnabled = true
end

function HasSimSpeedBalancer(player, version)

	for index, client in pairs(GetSessionClients()) do
        if client.name == player then
			moddedClients[index] = index
        end
    end

	if ChatController and ChatController.AppendEntry then
                    ChatController.AppendEntry({Name = "SimSpeedBalancer:", 
                                      Text=string.format("%s is on version %i", player, version),
                                      Color ="ffffff",
                                      BodyColor = "ffffff",
                                      ArmyID    = 0,
                                      Recipient = GetFocusArmy(),
                                      })
                end
end

function GetUnknownClients()

	for index, client in pairs(GetSessionClients()) do

		if GetFocusArmy() == index then
			moddedClients[index] = index
		end

		if moddedClients[index] ~= index then

			if ChatController and ChatController.AppendEntry then
			ChatController.AppendEntry({Name = "SimSpeedBalancer:", 
                                      Text=string.format("%s is unknown", client.name),
                                      Color ="ffffff",
                                      BodyColor = "ffffff",
                                      ArmyID    = 0,
                                      Recipient = GetFocusArmy(),
                                      })
			end
		end
    end
	

end


function GameWasPaused(bool)
	wasPaused = bool
end


function IncreasePlayerSpeed()
	increaseSpeed = true
	playerSetSpeed = playerSetSpeed + 1
end

function SetPlayerSpeed(speed)
	playerSetSpeed = speed
end

function DecreasePlayerSpeed()
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
--#endregion


--#region UI functions

--TODO: only fetch elements if they exist, otherwise it will do the full window and read zero cus of all the zero elements when I reset the buffer
---@param tickWindow integer
function GetTicksPerSecond(tickWindow)
    local ticksPerSecond = 0

    local currentArraySize = tickTimeHistory.count

    if currentArraySize > 0 and tickWindow <= tickHistoryMaxSize then

        -- 1. Calculate the correct index by stepping backwards from 'tail'
        local readIndex = tickTimeHistory.tail - tickWindow
        
        -- 2. Wrap around to the back of the array if we went below 1
        if readIndex <= 0 then
            readIndex = readIndex + tickTimeHistory.limit
        end

		if currentArraySize < tickWindow then
			readIndex = tickTimeHistory.tail - tickTimeHistory.count
		end
		if readIndex <= 0 then
            readIndex = readIndex + tickTimeHistory.limit
        end

        -- 3. Grab the history using the calculated index
        local oldTime = tickTimeHistory.items[readIndex]
        local oldTick = tickNumHistory.items[readIndex]


        local deltaTime = currentRealTime - oldTime
        local tickDelta = currentGameTick - oldTick
        
        if tickDelta == 0 then return 0 end
        
        local realDelta = deltaTime / tickDelta

        ticksPerSecond = 1 / realDelta
    end

    if tickWindow > tickHistoryMaxSize then
        LOG2("Tick window too large, increase the tickHistoryMaxSize")
    end

    return ticksPerSecond
end

function CreateReadoutsDisplay(parent)

	if controls.SSBbg then
	   controls.SSBbg:Destroy()
	end

	controls.SSBbg = Group(parent)
    controls.SSBbg.Depth:Set(10)
	controls.SSBbg.Left:Set(function()
    return parent.Left() + parent.Width() * 0.59
	end)
	controls.SSBbg.Top:Set(function()
    return parent.Top() + parent.Height() * 0.03 - 20   -- 2% down from the top
    end)

	controls.SSBbg.main = Group(controls.SSBbg)
	LayoutHelpers.AtLeftTopIn(controls.SSBbg.main, controls.SSBbg, 0, 0)


	controls.SSBbgTop = Bitmap(controls.SSBbg)
    controls.SSBbgTop:SetTexture(UIUtil.UIFile('/game/score-panel/panel-score_bmp_b.dds'))
    LayoutHelpers.AtLeftTopIn(controls.SSBbgTop, controls.SSBbg, -13, 18)
	controls.SSBbgTop.Width:Set(LayoutHelpers.ScaleNumber(175))
	controls.SSBbgTop.Height:Set(LayoutHelpers.ScaleNumber(-15))


	controls.SSBbgBottom = Bitmap(controls.SSBbg)
    controls.SSBbgBottom:SetTexture(UIUtil.UIFile('/game/score-panel/panel-score_bmp_b.dds'))
    LayoutHelpers.AtLeftTopIn(controls.SSBbgBottom, controls.SSBbg, -13, 18)
	controls.SSBbgBottom.Width:Set(LayoutHelpers.ScaleNumber(175))
	controls.SSBbgBottom.Height:Set(LayoutHelpers.ScaleNumber(15))

	controls.SSBbg.main.Height:Set(LayoutHelpers.ScaleNumber(35))
	controls.SSBbg.main.Width:Set(LayoutHelpers.ScaleNumber(150))


	LayoutHelpers.SetDimensions(controls.SSBbg, 0, 0)
    controls.SSBcollapseArrow = UIUtil.CreateCollapseArrow(controls.SSBbg, "t")
	controls.SSBcollapseArrow:EnableHitTest(true)
    controls.SSBcollapseArrow.OnCheck = function(self, checked)
        ToggleReadouts(not checked)
    end
    Tooltip.AddCheckboxTooltip(controls.SSBcollapseArrow,  {
    	text = "Collapse/Expand"})

	controls.tickRateReadout = UIUtil.CreateText(controls.SSBbg.main, "TPS:", 12, UIUtil.bodyFont, true)
	controls.tickRateReadout:SetColor('ff00C4E2')
	controls.tickRateReadout:EnableHitTest(true)

    controls.avgTickrate = UIUtil.CreateText(controls.SSBbg.main, '00.0', 13, UIUtil.bodyFont, true)
    controls.avgTickrate:SetColor('ff00dbff')
	controls.avgTickrate:EnableHitTest(true)
	Tooltip.AddControlTooltip(controls.avgTickrate, {
    	text = "Tickrate",
    	body = "averaged 5 second readout, may fluctuate based on game conditions and mod behavior",}, 0)
	Tooltip.AddControlTooltip(controls.tickRateReadout, {
    	text = "Tickrate",
    	body = "averaged 5 second readout, may fluctuate based on game conditions and mod behavior",}, 0)

	local str = string.format("/ %03.1f", TARGET_TICKRATE*10)

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


	controls.divergenceText = UIUtil.CreateText(controls.SSBbg.main, '0', 12, UIUtil.bodyFont, true)
    controls.divergenceText:SetColor('ff00ff00')
	controls.divergenceText:EnableHitTest(true)
    Tooltip.AddControlTooltip(controls.divergenceText, {
    	text = "Divergence",
		body = "Seconds behind real time that the game is experiencing",}, 0)

	controls.maximumDivergence = UIUtil.CreateText(controls.SSBbg.main, '/ '.. MAX_RECOVERY_LENGTH ..".00s", 10, UIUtil.bodyFont, true)
    controls.maximumDivergence:SetColor('FFFFFFFF')
	controls.maximumDivergence:EnableHitTest(true)
    Tooltip.AddControlTooltip(controls.maximumDivergence, {
    	text = "Maximum Divergence",
		body = "The maximum divergence that can be recovered (set by Maximum Recovery Length)",}, 0)

	controls.SimSpeedBalancerInfo = UIUtil.CreateText(controls.SSBbg.main, 'Sim Speed Balancer UI' .. " - v" .. modVersion, 10, UIUtil.bodyFont, true)
    controls.SimSpeedBalancerInfo:SetColor('AAAAAA')

	LayoutHelpers.AtLeftTopIn(controls.tickRateReadout, controls.SSBbg.main, -5, 10)

    LayoutHelpers.AtRightTopIn(controls.avgTickrate, controls.tickRateReadout, -29, -4)
	LayoutHelpers.AtLeftTopIn(controls.targTickrate, controls.tickRateReadout, 31, 9)

    LayoutHelpers.AtLeftTopIn(controls.slowdownText, controls.SSBbg.main, 105, (6))

    LayoutHelpers.AtLeftTopIn(controls.speedupText, controls.slowdownText, 0, (11))

	LayoutHelpers.AtLeftTopIn(controls.divergenceText, controls.SSBbg.main, 63, 6)
	LayoutHelpers.AtLeftTopIn(controls.maximumDivergence, controls.SSBbg.main, 61, 18)


	LayoutHelpers.AtLeftTopIn(controls.SSBcollapseArrow, controls.SSBbg, 0, -15)

	LayoutHelpers.AtLeftTopIn(controls.SimSpeedBalancerInfo, controls.SSBbg.main, 30, -10)

	controls.SSBstatus = UIUtil.CreateText(controls.SSBbg.main, "", 12, UIUtil.bodyFont, true)
	controls.SSBstatus:SetColor('FFE20000')

	if GetFocusArmy() == TOGGLE_PLAYER or SessionIsReplay() then
		controls.SSBbutton = UIUtil.CreateButtonStd(controls.SSBbg, '/widgets02/small', "Toggle SimSpeedBalancer", 12, 0)
		controls.SSBbutton.label:SetFont(UIUtil.bodyFont, 10)
		controls.SSBbutton.OnClick = function(self, modifiers)
			ToggleEnabled()
		end
		LayoutHelpers.AtLeftTopIn(controls.SSBbutton, controls.SSBbg.main, 0, 30)

		
	end

	LayoutHelpers.AtLeftTopIn(controls.SSBstatus, controls.SSBbg.main, -45, 10)


   -- Determine who to send data to
    for index, client in pairs(GetSessionClients()) do
        if client.name ~= myName then
			validClients[index] = index
        end
    end

	if not SessionIsReplay() and table.getn(GetSessionClients()) > 1 and ChatController and ChatController.AppendEntry then
		ChatController.AppendEntry({Name = "SimSpeedBalancer:", 
							Text=string.format("You are on version %i", modVersion),
							Color ="ffffff",
							BodyColor = "ffffff",
							ArmyID    = 0,
							Recipient = GetFocusArmy(),
							})
		SessionSendChatMessage(validClients, { Identifier = 'SimSpeedBalancer', version = modVersion })
                end


	if LOGGING_ENABLED == 1 then
		LOG2("Mod Enabled | Game Tick | Real Time | Sim Time | Current Divergence | Divergence Change")
	end
end

function GetTotalSlowdown()
	return FormatTime(totalSlowdown)
end
function GetTotalSpeedup()
	return FormatTime(math.abs(totalSpeedup))
end

-- Show and hide TPS, slow time, and fast time readouts
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
			controls.SSBbutton:Show()
            local sound = Sound({Cue = "UI_Score_Window_Open", Bank = "Interface",})
            PlaySound(sound)

		else
			local sound = Sound({Cue = "UI_Score_Window_Close", Bank = "Interface",})
			PlaySound(sound)
			controls.SSBbg.main:Hide()
			controls.SSBbgTop:Hide()
			controls.SSBbgBottom:Hide()
			controls.SSBbutton:Hide()

        end

    end

end
--#endregion


--#region Generic Utility functions
function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
	local m = math.floor(math.mod(seconds, 3600) / 60)
	local s = math.floor(math.mod(seconds, 60))
    return string.format(" %02d:%02d:%02d", h, m, s)
end


--#endregion
