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

local modVersion = 21

local OPTIONS = SessionGetScenarioInfo().Options

local GAMESPEED_OPTION = OPTIONS.GameSpeed or 0


-- max length the slow time buffer can hold (ex: =5 means freezing for 10 seconds will only fast forward until 5 seconds is recovered)
local MAX_RECOVERY_LENGTH = tonumber(OPTIONS.SSB_MaxRecovery) or 3.0


local TARGET_TICKRATE = tonumber(OPTIONS.SSB_TargetTickrate) or 1

local TOGGLE_PLAYER = tonumber(OPTIONS.SSB_TogglePlayer) or 1

local LOGGING_ENABLED = false


local armies = GetArmiesTable().armiesTable
myArmyId = GetFocusArmy()
local myName = armies[myArmyId].nickname

local validClients = {}

--#endregion


--#region UI variables
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")
local UIUtil = import("/lua/ui/uiutil.lua")
local Tooltip = import("/lua/ui/game/tooltip.lua")
local Bitmap = import("/lua/maui/bitmap.lua").Bitmap
local Group = import("/lua/maui/group.lua").Group


local createdUI = false

-- The readouts panel's controls (CreateReadoutsDisplay).
local panel = {}

-- What the ReUI options set (RegisterOptions). Without ReUI these stand.
local settings = {
	showLogButton = true,
	startCollapsed = false,
}

-- place: where the panel was dragged to, { edge = 'l' | 'r' | 't', along = 0..1 }, or false for its usual spot.
-- loaded: place was read from the profile. editing: the ReUI options window is open.
-- collapsed: folded (nil until the panel is first made: settings.startCollapsed). registered: RegisterOptions ran.
local layout = { place = false, loaded = false, editing = false, collapsed = nil, registered = false }

-- Each player's Sim Speed Balancer version, by name, as they reported it.
-- checked: everyone has had the chance to report (GetUnknownClients).
local versions = { byName = {}, checked = false }

local OPTIONS_KEY = 'SimSpeedBalancer'
local PLACE_KEY = 'SimSpeedBalancerPanelPlace'
local HINT_COLOR = 'ffffd24a'


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
			RegisterOptions()
			CreateReadoutsDisplay(GetFrame(0))
			AnnounceVersion()
			createdUI = true
		else
			UpdateReadouts()
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

		if LOGGING_ENABLED then
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
	if panel.status then
		panel.status:SetText("OFF")
	end
	modEnabled = false
	SetGameSpeed(0)
end

function ToggleEnabledOn()
	if panel.status then
		panel.status:SetText("")
	end
	currentDivergence = 0
	modEnabled = true
end

function HasSimSpeedBalancer(player, version)
	versions.byName[player] = version
	PaintTitle()
end

--- Everyone has had the chance to report their version: those who didn't show as "none".
function GetUnknownClients()
	versions.checked = true
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

	if panel.root then
		panel.root:Destroy()
	end
	panel = {}
	LoadPlace()

	local edge = Edge()

	local root = Group(parent)
	panel.root = root
	root.Depth:Set(10)
	LayoutHelpers.SetDimensions(root, 0, 0)

	local main = Group(root)
	panel.main = main
	LayoutHelpers.AtLeftTopIn(main, root, 0, 0)


	panel.bgTop = Bitmap(root)
	panel.bgTop:SetTexture(UIUtil.UIFile('/game/score-panel/panel-score_bmp_b.dds'))
	LayoutHelpers.AtLeftTopIn(panel.bgTop, root, -13, 18)
	panel.bgTop.Width:Set(LayoutHelpers.ScaleNumber(175))
	panel.bgTop.Height:Set(LayoutHelpers.ScaleNumber(-15))


	panel.bgBottom = Bitmap(root)
	panel.bgBottom:SetTexture(UIUtil.UIFile('/game/score-panel/panel-score_bmp_b.dds'))
	LayoutHelpers.AtLeftTopIn(panel.bgBottom, root, -13, 18)
	panel.bgBottom.Width:Set(LayoutHelpers.ScaleNumber(175))
	panel.bgBottom.Height:Set(LayoutHelpers.ScaleNumber(15))

	main.Height:Set(LayoutHelpers.ScaleNumber(35))
	main.Width:Set(LayoutHelpers.ScaleNumber(150))


	local logButton = Bitmap(root)
	panel.logButton = logButton
	LayoutHelpers.SetDimensions(logButton, 13, 13)
	logButton.label = UIUtil.CreateText(logButton, "L", 10, UIUtil.bodyFont, true)
	logButton:EnableHitTest()
	logButton.label:DisableHitTest(true)
	PaintLogButton()

	logButton.HandleEvent = function(self, event)
		if event.Type == 'ButtonPress' and event.Modifiers.Left then
			if not LOGGING_ENABLED then
				LOG2("Mod Enabled | Game Tick | Real Time | Sim Time | Current Divergence | Divergence Change")
				LOGGING_ENABLED = true
			else
				LOGGING_ENABLED = false
			end
			PaintLogButton()
		end
	end

	Tooltip.AddCheckboxTooltip(logButton,  {
	text = "Toggle Performance Logging"})


	panel.tickRateReadout = UIUtil.CreateText(main, "TPS:", 12, UIUtil.bodyFont, true)
	panel.tickRateReadout:SetColor('ff00C4E2')
	panel.tickRateReadout:EnableHitTest(true)

	panel.avgTickrate = UIUtil.CreateText(main, '00.0', 13, UIUtil.bodyFont, true)
	panel.avgTickrate:SetColor('ff00dbff')
	panel.avgTickrate:EnableHitTest(true)
	Tooltip.AddControlTooltip(panel.avgTickrate, {
		text = "Tickrate",
		body = "averaged 5 second readout, may fluctuate based on game conditions and mod behavior",}, 0)
	Tooltip.AddControlTooltip(panel.tickRateReadout, {
		text = "Tickrate",
		body = "averaged 5 second readout, may fluctuate based on game conditions and mod behavior",}, 0)

	local str = string.format("/ %03.1f", TARGET_TICKRATE*10)

	panel.targTickrate = UIUtil.CreateText(main, str, 9.5, UIUtil.bodyFont, true)
	panel.targTickrate:SetColor('ff00C4E2')
	panel.targTickrate:EnableHitTest(true)
	Tooltip.AddControlTooltip(panel.targTickrate, {
		text = "Target Tickrate",
		body = "Lobby set minimum tickrate",}, 0.1)



	panel.slowdownText = UIUtil.CreateText(main, '00:00:00', 11, UIUtil.bodyFont, true)
	panel.slowdownText:SetColor('ffffff00')
	panel.slowdownText:EnableHitTest(true)

	Tooltip.AddControlTooltip(panel.slowdownText, {
		text = "Slow Time",
		body = "The total time the sim is behind real time since starting",},0)

	panel.speedupText = UIUtil.CreateText(main, '00:00:00', 11, UIUtil.bodyFont, true)
	panel.speedupText:SetColor('ff00ff00')
	panel.speedupText:EnableHitTest(true)
	Tooltip.AddControlTooltip(panel.speedupText, {
		text = "Fast Time",
		body = "The total time that has been recouped from Slow Time",}, 0)


	panel.divergenceText = UIUtil.CreateText(main, '0', 12, UIUtil.bodyFont, true)
	panel.divergenceText:SetColor('ff00ff00')
	panel.divergenceText:EnableHitTest(true)
	Tooltip.AddControlTooltip(panel.divergenceText, {
		text = "Divergence",
		body = "Seconds behind real time that the game is experiencing",}, 0)

	panel.maximumDivergence = UIUtil.CreateText(main, '/ '.. MAX_RECOVERY_LENGTH ..".00s", 10, UIUtil.bodyFont, true)
	panel.maximumDivergence:SetColor('FFFFFFFF')
	panel.maximumDivergence:EnableHitTest(true)
	Tooltip.AddControlTooltip(panel.maximumDivergence, {
		text = "Maximum Divergence",
		body = "The maximum divergence that can be recovered (set by Maximum Recovery Length)",}, 0)

	-- Hovering the title lists every player's Sim Speed Balancer version.
	local title = UIUtil.CreateText(main, 'Sim Speed Balancer' .. " - v" .. modVersion, 10, UIUtil.bodyFont, true)
	panel.title = title
	title:EnableHitTest(true)
	title.HandleEvent = function(self, event)
		if event.Type == 'MouseEnter' then
			Tooltip.CreateMouseoverDisplay(self, { text = "Sim Speed Balancer versions", body = VersionList() }, 0, true)
		elseif event.Type == 'MouseExit' then
			Tooltip.DestroyMouseoverDisplay()
		end
		return false
	end

	LayoutHelpers.AtLeftTopIn(panel.tickRateReadout, main, -5, 10)

	LayoutHelpers.AtRightTopIn(panel.avgTickrate, panel.tickRateReadout, -29, -4)
	LayoutHelpers.AtLeftTopIn(panel.targTickrate, panel.tickRateReadout, 31, 9)

	LayoutHelpers.AtLeftTopIn(panel.slowdownText, main, 105, (6))

	LayoutHelpers.AtLeftTopIn(panel.speedupText, panel.slowdownText, 0, (11))

	LayoutHelpers.AtLeftTopIn(panel.divergenceText, main, 63, 6)
	LayoutHelpers.AtLeftTopIn(panel.maximumDivergence, main, 61, 18)

	LayoutHelpers.AtLeftTopIn(logButton, root, -13, -10)
	LayoutHelpers.AtLeftTopIn(logButton.label, logButton, 3, 0)

	LayoutHelpers.AtLeftTopIn(title, main, 30, -10)

	-- Underlined, to say it can be hovered.
	local underline = Bitmap(main)
	panel.titleLine = underline
	underline:DisableHitTest()
	underline.Left:Set(function() return title.Left() end)
	-- (The text's height has room under the letters: up into it a little.)
	underline.Top:Set(function() return title.Top() + title.Height() - LayoutHelpers.ScaleNumber(2) end)
	underline.Width:Set(function() return title.Width() end)
	underline.Height:Set(function() return math.max(1, math.floor(LayoutHelpers.ScaleNumber(1))) end)
	PaintTitle()

	panel.status = UIUtil.CreateText(main, modEnabled and "" or "OFF", 12, UIUtil.bodyFont, true)
	panel.status:SetColor('FFE20000')

	if GetFocusArmy() == TOGGLE_PLAYER or SessionIsReplay() then
		panel.toggleButton = UIUtil.CreateButtonStd(root, '/widgets02/small', "Toggle SimSpeedBalancer", 12, 0)
		panel.toggleButton.label:SetFont(UIUtil.bodyFont, 10)
		panel.toggleButton.OnClick = function(self, modifiers)
			ToggleEnabled()
		end
		LayoutHelpers.AtLeftTopIn(panel.toggleButton, main, 0, 30)


	end

	-- On the left edge there is no room to its left: after the readouts instead.
	if edge == 'l' then
		LayoutHelpers.AtLeftTopIn(panel.status, main, 170, 10)
	else
		LayoutHelpers.AtLeftTopIn(panel.status, main, -45, 10)
	end

	-- On a side edge the title and the toggle button line up with that side of the
	-- readouts' background (-13 .. 162), not where they sit under the top tab.
	if edge == 'l' then
		LayoutHelpers.AtLeftTopIn(title, main, 4, -10)   -- just past the logging button
		if panel.toggleButton then
			LayoutHelpers.AtLeftTopIn(panel.toggleButton, main, -13, 30)
		end
	elseif edge == 'r' then
		-- The logging button goes to the right-hand corner, the title just before it.
		logButton.Left:Set(function() return root.Left() + LayoutHelpers.ScaleNumber(162) - logButton.Width() end)
		title.Left:Set(function() return logButton.Left() - LayoutHelpers.ScaleNumber(4) - title.Width() end)
		if panel.toggleButton then
			local button = panel.toggleButton
			button.Left:Set(function() return main.Left() + LayoutHelpers.ScaleNumber(162) - button.Width() end)
		end
	end

	Place()
	SetUpTab(edge)

	if layout.editing then
		panel.hints = DragHints(edge)
		panel.reset = ResetButton(edge)
	end

	if layout.collapsed == nil then
		layout.collapsed = settings.startCollapsed and true or false
	end
	if layout.collapsed then
		panel.arrow:SetCheck(true, true)
	end
	ShowParts()
end

--- Tell the other players which version you are on (shown in the title's tooltip).
function AnnounceVersion()
	-- Determine who to send data to
	for index, client in pairs(GetSessionClients()) do
		if client.name ~= myName then
			validClients[index] = index
		end
	end

	if not SessionIsReplay() and table.getn(GetSessionClients()) > 1 then
		SessionSendChatMessage(validClients, { Identifier = 'SimSpeedBalancer', version = modVersion })
	end
end

--- Every player and the version they reported: "none" once they had their chance and didn't.
function VersionList()
	if SessionIsReplay() then
		return "Versions are not recorded in replays"
	end
	local lines = {}
	for _, client in ipairs(GetSessionClients()) do
		local version
		if client['local'] then
			version = "v" .. modVersion .. " (you)"
		elseif versions.byName[client.name] then
			version = "v" .. versions.byName[client.name]
		elseif versions.checked then
			version = "none"
		else
			version = "?"
		end
		table.insert(lines, client.name .. ": " .. version)
	end
	return table.concat(lines, "\n")
end

--- Grey title, orange when someone reported a different version.
function PaintTitle()
	if not panel.title then
		return
	end
	local differs = false
	for _, version in pairs(versions.byName) do
		if version ~= modVersion then
			differs = true
		end
	end
	local color = differs and 'FFFF9933' or 'AAAAAA'
	panel.title:SetColor(color)
	panel.titleLine:SetSolidColor(color)
end

function PaintLogButton()
	if not panel.logButton then
		return
	end
	if LOGGING_ENABLED then
		panel.logButton.label:SetColor('FF000000')
		panel.logButton:SetSolidColor('FF17CCEC')
	else
		panel.logButton.label:SetColor('8DFFFFFF')
		panel.logButton:SetSolidColor('9D151715')
	end
end

--- Bring the readouts up to date (each beat).
function UpdateReadouts()
	if not panel.root then
		return
	end
	if avgTimePerTick10 then
		panel.avgTickrate:SetText(string.format("%03.1f", avgTimePerTick10))
	end
	if currentDivergence <= 1 then
		panel.divergenceText:SetColor('ff00ff00')
		panel.divergenceText:SetText(string.format("%03.2fs", currentDivergence))

	elseif currentDivergence <= 2 then
		panel.divergenceText:SetColor('ffffff00')
		panel.divergenceText:SetText(string.format("%03.2f", currentDivergence))
	elseif currentDivergence <= 3 then
		panel.divergenceText:SetColor('FFFF0000')
		panel.divergenceText:SetText(string.format("%03.2fs", currentDivergence))
	end

	panel.slowdownText:SetText(GetTotalSlowdown())
	panel.speedupText:SetText(GetTotalSpeedup())
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

	if not panel.main then
		return
	end

	layout.collapsed = not checked
	ShowParts()
	if checked then
		PlaySound(Sound({Cue = "UI_Score_Window_Open", Bank = "Interface",}))
	else
		PlaySound(Sound({Cue = "UI_Score_Window_Close", Bank = "Interface",}))
	end
end

--- Show what should be: everything but the tab folds away, the logging button only if the option is on.
function ShowParts()
	if not panel.root then
		return
	end
	local open = not layout.collapsed
	for _, control in pairs({ panel.main, panel.bgTop, panel.bgBottom, panel.toggleButton, panel.reset }) do
		if open then
			control:Show()
		else
			control:Hide()
		end
	end
	if open and settings.showLogButton then
		panel.logButton:Show()
	else
		panel.logButton:Hide()
	end
end
--#endregion


--#region Panel placement (dragged by its tab while the ReUI options window is open)

-- How far the readouts reach around the panel's anchor (unscaled), for keeping it on the screen.
local BOX_LEFT, BOX_RIGHT, BOX_TOP, BOX_BOTTOM = -15, 165, -12, 35

--- How far down the panel reaches: further with the toggle button under it.
local function BoxBottom()
	return panel.toggleButton and 60 or BOX_BOTTOM
end

--- The edge the panel is on.
function Edge()
	return layout.place and layout.place.edge or 't'
end

--- The saved spot, read from the profile once.
function LoadPlace()
	if layout.loaded then
		return
	end
	layout.loaded = true
	pcall(function()
		local saved = import('/lua/user/prefs.lua').GetFromCurrentProfile(PLACE_KEY)
		if type(saved) == 'table' and (saved.edge == 'l' or saved.edge == 'r' or saved.edge == 't')
			and type(saved.along) == 'number' and saved.along == saved.along then
			layout.place = { edge = saved.edge, along = math.max(0, math.min(1, saved.along)) }
		end
	end)
end

--- Keep the spot in the profile (none: the usual spot).
function SavePlace()
	pcall(function()
		local place = layout.place
		import('/lua/user/prefs.lua').SetToCurrentProfile(PLACE_KEY,
			place and { edge = place.edge, along = place.along } or nil)
		SavePreferences()
	end)
end

--- Put the panel's anchor where layout.place says (none: under the top of the screen, right of centre).
function Place()
	local root, frame = panel.root, GetFrame(0)
	local S = LayoutHelpers.ScaleNumber
	local place = layout.place
	if not place then
		root.Left:Set(function() return frame.Left() + frame.Width() * 0.59 end)
		root.Top:Set(function() return frame.Top() + frame.Height() * 0.03 - 20 end)
		return
	end
	local along = place.along
	if place.edge == 't' then
		root.Left:Set(function() return frame.Left() + S(-BOX_LEFT) + (frame.Width() - S(BOX_RIGHT - BOX_LEFT)) * along end)
		root.Top:Set(function() return frame.Top() + frame.Height() * 0.03 - 20 end)
		return
	end
	local bottom = BoxBottom()
	if place.edge == 'r' then
		root.Left:Set(function() return frame.Left() + frame.Width() - S(BOX_RIGHT + 16) end)
	else
		root.Left:Set(function() return frame.Left() + S(-BOX_LEFT + 16) end)
	end
	root.Top:Set(function() return frame.Top() + S(-BOX_TOP) + (frame.Height() - S(bottom - BOX_TOP)) * along end)
end

--- Show or take down the tooltip on the tab while it can be dragged.
local function DragTip(control)
	if control then
		Tooltip.CreateMouseoverDisplay(control, { text = "Move the panel",
			body = "Drag this tab along the left, right or top edge of the screen. Click it to fold the panel." }, 0, true)
	else
		Tooltip.DestroyMouseoverDisplay()
	end
end

--- The tab, as FAF puts its own on that edge: folds the panel, and drags it while the ReUI options window is open.
function SetUpTab(edge)
	local root, frame = panel.root, GetFrame(0)
	local S = LayoutHelpers.ScaleNumber
	local arrow = UIUtil.CreateCollapseArrow(root, edge)
	panel.arrow = arrow
	arrow:EnableHitTest(true)
	if edge == 't' then
		LayoutHelpers.AtLeftTopIn(arrow, root, 0, -15)
	else
		-- Beside the readouts, just past the screen's edge.
		arrow.Top:Set(function() return root.Top() + S((BOX_TOP + BOX_BOTTOM) / 2) - arrow.Height() / 2 end)
		if edge == 'r' then
			arrow.Left:Set(function() return frame.Left() + frame.Width() - arrow.Width() + S(3) end)
		else
			arrow.Left:Set(function() return frame.Left() - S(3) end)
		end
	end
	arrow.OnCheck = function(self, checked)
		ToggleReadouts(not checked)
	end
	Tooltip.AddCheckboxTooltip(arrow,  {
		text = "Collapse/Expand"})

	local handle = arrow.HandleEvent
	arrow.HandleEvent = function(self, event)
		local t = event.Type
		if layout.editing and (t == 'ButtonPress' or t == 'ButtonDClick')
			and not (event.Modifiers and event.Modifiers.Right) and StartDrag(event) then
			return true
		end
		local result = handle and handle(self, event) or false
		if layout.editing and t == 'MouseEnter' then
			DragTip(self)
		end
		return result
	end
end

--- A small solid triangle pointing 'u', 'd', 'l' or 'r', from lines of bitmaps (no texture to go missing).
local function Triangle(dir)
	local tri = Group(panel.root)
	if dir == 'u' or dir == 'd' then
		LayoutHelpers.SetDimensions(tri, 7, 4)
	else
		LayoutHelpers.SetDimensions(tri, 4, 7)
	end
	tri:DisableHitTest()
	for i = 0, 3 do
		local line = Bitmap(tri)
		line:SetSolidColor(HINT_COLOR)
		line:DisableHitTest()
		if dir == 'u' or dir == 'd' then
			LayoutHelpers.AtLeftTopIn(line, tri, 3 - i, dir == 'u' and i or 3 - i)
			LayoutHelpers.SetDimensions(line, 2 * i + 1, 1)
		else
			LayoutHelpers.AtLeftTopIn(line, tri, dir == 'l' and i or 3 - i, 3 - i)
			LayoutHelpers.SetDimensions(line, 1, 2 * i + 1)
		end
	end
	return tri
end

--- Little arrows either side of the tab, the ways it can be dragged.
function DragHints(edge)
	local arrow = panel.arrow
	local a, b
	if edge == 't' then
		a, b = Triangle('l'), Triangle('r')
		a.Left:Set(function() return arrow.Left() - a.Width() - 2 end)
		b.Left:Set(function() return arrow.Left() + arrow.Width() + 2 end)
		a.Top:Set(function() return arrow.Top() + (arrow.Height() - a.Height()) / 2 end)
		b.Top:Set(function() return arrow.Top() + (arrow.Height() - b.Height()) / 2 end)
	else
		a, b = Triangle('u'), Triangle('d')
		a.Left:Set(function() return arrow.Left() + (arrow.Width() - a.Width()) / 2 end)
		b.Left:Set(function() return arrow.Left() + (arrow.Width() - b.Width()) / 2 end)
		a.Top:Set(function() return arrow.Top() - a.Height() - 2 end)
		b.Top:Set(function() return arrow.Top() + arrow.Height() + 2 end)
	end
	a.Depth:Set(function() return arrow.Depth() + 1 end)
	b.Depth:Set(function() return arrow.Depth() + 1 end)
	return { a, b }
end

--- A small "Reset position" button under the readouts (over them, if there is no room under them). Folds away with them.
function ResetButton(edge)
	local root, frame = panel.root, GetFrame(0)
	local S = LayoutHelpers.ScaleNumber
	local bottom = BoxBottom()
	local back = Bitmap(root)
	back:SetSolidColor('CC0A0E14')
	LayoutHelpers.SetDimensions(back, 96, 18)
	if edge == 'r' then
		back.Left:Set(function() return root.Left() + S(BOX_RIGHT) - back.Width() end)
	else
		back.Left:Set(function() return root.Left() + S(BOX_LEFT) end)
	end
	back.Top:Set(function()
		local below = root.Top() + S(bottom + 4)
		if below + back.Height() > frame.Top() + frame.Height() then
			return root.Top() + S(BOX_TOP - 4) - back.Height()
		end
		return below
	end)

	local text = UIUtil.CreateText(back, "Reset position", 10, UIUtil.bodyFont, true)
	text:SetColor('FFAAAAAA')
	text:DisableHitTest()
	text.Left:Set(function() return back.Left() + (back.Width() - text.Width()) / 2 end)
	text.Top:Set(function() return back.Top() + (back.Height() - text.Height()) / 2 end)

	back.HandleEvent = function(self, event)
		if event.Type == 'MouseEnter' then
			text:SetColor('FFFFFFFF')
		elseif event.Type == 'MouseExit' then
			text:SetColor('FFAAAAAA')
		elseif event.Type == 'ButtonPress' then
			PlaySound(Sound({ Cue = 'UI_Menu_MouseDown_Sml', Bank = 'Interface' }))
			ResetPlace()
			return true
		end
		return false
	end
	return back
end

--- How far v is through room, 0..1.
local function Fraction(v, room)
	if room <= 0 then
		return 0
	end
	return math.max(0, math.min(1, v / room))
end

--- The tab dragged to (x, y): onto the nearest of the three edges, with the tab under the pointer. A new edge needs a new tab: rebuilt.
function DragTo(x, y)
	local frame = GetFrame(0)
	if not panel.root or not frame then
		return
	end
	local S = LayoutHelpers.ScaleNumber
	local fl, ft, fw, fh = frame.Left(), frame.Top(), frame.Width(), frame.Height()
	local edge, nearest = 'l', x - fl
	if fl + fw - x < nearest then
		edge, nearest = 'r', fl + fw - x
	end
	if y - ft < nearest then
		edge = 't'
	end
	local along
	if edge == 't' then
		along = Fraction(x - fl - S(-BOX_LEFT), fw - S(BOX_RIGHT - BOX_LEFT))
	else
		local bottom = BoxBottom()
		along = Fraction(y - S((BOX_TOP + BOX_BOTTOM) / 2) - ft - S(-BOX_TOP), fh - S(bottom - BOX_TOP))
	end
	local was = Edge()
	layout.place = { edge = edge, along = along }
	if edge ~= was then
		CreateReadoutsDisplay(GetFrame(0))
		UpdateReadouts()
	else
		Place()
	end
end

--- A press on the tab while the ReUI options window is open: a drag moves the panel, a click without moving folds or opens it as usual.
function StartDrag(event)
	local ok, DraggerModule = pcall(import, '/lua/maui/dragger.lua')
	if not ok or not DraggerModule.Dragger then
		return false
	end
	local drag = DraggerModule.Dragger()
	local startX, startY = event.MouseX or 0, event.MouseY or 0
	local moved = false
	drag.OnMove = function(self, x, y)
		if not moved and math.abs(x - startX) + math.abs(y - startY) < 4 then
			return
		end
		moved = true
		DragTo(x, y)
	end
	drag.OnRelease = function(self, x, y)
		if moved then
			SavePlace()
		elseif panel.arrow then
			panel.arrow:SetCheck(not layout.collapsed)
		end
		self:Destroy()
	end
	drag.OnCancel = function(self)
		if moved then
			SavePlace()
		end
		self:Destroy()
	end
	PostDragger(GetFrame(0), event.KeyCode, drag)
	return true
end

--- The ReUI options window opened or closed: while it is open the panel's tab drags it, with a reset button under it.
function SetEditing(on)
	on = on and true or false
	if layout.editing == on then
		return
	end
	layout.editing = on
	DragTip()
	if panel.root then
		CreateReadoutsDisplay(GetFrame(0))
		UpdateReadouts()
	end
end

--- Back to the usual spot, and forget the saved one.
function ResetPlace()
	layout.place = false
	SavePlace()
	if panel.root then
		CreateReadoutsDisplay(GetFrame(0))
		UpdateReadouts()
	end
end
--#endregion


--#region ReUI options (only with ReUI installed)

--- An option's value, whichever shape ReUI gave it.
local function ReadOption(option)
	if type(option.Get) == 'function' then
		return option:Get()
	end
	return option()
end

--- Call fn(value) whenever an option changes, whichever shape it is.
local function WatchOption(option, fn)
	if option.OnChanged and option.OnChanged.Add then
		option.OnChanged:Add(function(changed, value) fn(value) end)
		return
	end
	local previous = option.OnChange
	option.OnChange = function(self)
		if previous then
			previous(self)
		end
		fn(ReadOption(self))
	end
end

--- With ReUI: our options in its options window, its saved values into settings. ReUI only loads ui_only mods itself,
--- so this is done from here (both the sim and the UI version).
function RegisterOptions()
	if layout.registered then
		return
	end
	layout.registered = true
	local ReUI = rawget(_G, 'ReUI')
	if not ReUI then
		return
	end
	local ok, err = pcall(function()
		local Options = ReUI.Options
		local Make = Options.OptionValue or Options.Opt
		Options.Mods[OPTIONS_KEY] = {
			showLogButton = Make(settings.showLogButton),
			startCollapsed = Make(settings.startCollapsed),
		}
		local values = Options.Mods[OPTIONS_KEY]
		for key, option in pairs(values) do
			local name = key
			settings[name] = ReadOption(option) and true or false
			WatchOption(option, function(value)
				settings[name] = value and true or false
				ShowParts()
			end)
		end

		local Builder = Options.Builder
		local build = {
			Builder.Title("Readouts panel", 14),
			Builder.Filter("Show the logging button", values.showLogButton),
			Builder.Filter("Panel starts folded", values.startCollapsed),
		}
		-- ReUI's own window, told to us so the panel can be moved while it is open.
		Builder.AddOptions(OPTIONS_KEY, "Sim Speed Balancer", function(parent)
			local OptionsWindow = import('/mods/ReUI/Options/Modules/OptionsWindow.lua').OptionsWindow
			local window = OptionsWindow(parent, "Sim Speed Balancer", OPTIONS_KEY, build)
			SetEditing(true)
			local destroy = window.OnDestroy
			window.OnDestroy = function(self)
				SetEditing(false)
				return destroy(self)
			end
			return window
		end)
	end)
	if not ok then
		LOG2("ReUI options unavailable: " .. tostring(err))
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
